import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/moderator_config.dart';
import 'models/contribution.dart';

/// Client tối giản cho Backend API (Laravel, /api/v1).
/// Mặc định offline-first: chỉ dùng khi người dùng chủ động gửi lên server.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : _explicitBaseUrl = baseUrl,
      _client = client ?? http.Client();

  final String? _explicitBaseUrl;

  /// Đọc lại mỗi lần dùng: người dùng đổi máy chủ trong Cài đặt thì các client
  /// đã tạo trước đó (repository, màn Đóng góp) áp dụng ngay, không cần restart.
  String get baseUrl => _explicitBaseUrl ?? ApiConfig.instance.baseUrl.value;
  final http.Client _client;

  /// Mạng "đen" (có WiFi nhưng không ra Internet) khiến request treo vô hạn,
  /// nên mọi lời gọi đều phải có hạn: hết hạn thì coi như offline.
  static const Duration _readTimeout = Duration(seconds: 12);
  static const Duration _writeTimeout = Duration(seconds: 20);

  Uri get _endpoint => Uri.parse('$baseUrl/api/v1/contributions');

  Uri _syncEndpoint(int lastPulledAt, {String? cursor}) {
    final params = <String, String>{
      'last_pulled_at': '$lastPulledAt',
      'page_size': '500',
      'cursor': ?cursor,
    };
    return Uri.parse(
      '$baseUrl/api/v1/sync/delta',
    ).replace(queryParameters: params);
  }

  /// Delta Sync (SRS §5): lấy các term thay đổi sau `lastPulledAt` (epoch giây).
  /// Server trả theo lô; `cursor` (next_cursor từ lô trước) lấy lô kế tiếp.
  /// Trả payload gốc (SyncNormalizer sẽ chuẩn hóa); null nếu lỗi/mất mạng.
  Future<Map<String, dynamic>?> syncDelta(
    int lastPulledAt, {
    String? cursor,
  }) async {
    try {
      final res = await _client
          .get(
            _syncEndpoint(lastPulledAt, cursor: cursor),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_readTimeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// FR-COMM-01: gửi đề xuất vào hàng chờ kiểm duyệt.
  Future<SubmitResult> submitContribution(Map<String, dynamic> body) async {
    try {
      final res = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_writeTimeout);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final row = data['data'] as Map<String, dynamic>?;
        return SubmitResult.ok(
          data['message'] as String? ?? 'Đã gửi đề xuất.',
          id: row?['id'] as String?,
        );
      }
      final detail = _firstError(res.body);
      return SubmitResult.fail(
        detail ?? 'Máy chủ từ chối (HTTP ${res.statusCode}).',
      );
    } catch (_) {
      return SubmitResult.fail(
        'Không kết nối được máy chủ. Đề xuất chưa được gửi.',
      );
    }
  }

  Map<String, String> _authHeaders(String token, {bool json = false}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    if (json) 'Content-Type': 'application/json',
  };

  /// FR-COMM-02: hàng chờ kiểm duyệt. Backend chỉ trả dữ liệu khi request có
  /// Bearer token moderator, nên thiếu token thì báo lỗi ngay, không gọi mạng.
  Future<ContributionsResult> fetchContributions({
    String status = Contribution.statusPending,
    int limit = 50,
  }) async {
    final token = ModeratorConfig.instance.token.value;
    if (token.isEmpty) {
      return ContributionsResult.error(
        'Chưa cấu hình token kiểm duyệt trong Cài đặt.',
      );
    }
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v1/contributions',
      ).replace(queryParameters: {'status': status, 'limit': '$limit'});
      final res = await _client
          .get(uri, headers: _authHeaders(token))
          .timeout(_readTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rows = (data['data'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Contribution.fromJson)
            .toList(growable: false);
        final meta = data['meta'] as Map<String, dynamic>?;
        return ContributionsResult.ok(
          rows,
          hasMore: meta?['has_more'] == true,
        );
      }
      return ContributionsResult.error(
        _moderationError(res.statusCode, res.body),
      );
    } catch (_) {
      return ContributionsResult.error(
        'Không kết nối được máy chủ. Kiểm tra địa chỉ trong Cài đặt.',
      );
    }
  }

  /// FR-COMM-02: duyệt đề xuất — server tự tạo term và ghi công contributor.
  Future<ModerationResult> approveContribution(String id) =>
      _reviewContribution(id, 'approve');

  /// FR-COMM-02: từ chối kèm ghi chú bắt buộc (server validate max 2000 ký tự).
  Future<ModerationResult> rejectContribution(String id, String note) =>
      _reviewContribution(id, 'reject', note: note);

  Future<ModerationResult> _reviewContribution(
    String id,
    String action, {
    String? note,
  }) async {
    final token = ModeratorConfig.instance.token.value;
    if (token.isEmpty) {
      return ModerationResult.fail(
        'Chưa cấu hình token kiểm duyệt trong Cài đặt.',
      );
    }
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/contributions/$id/$action'),
            headers: _authHeaders(token, json: true),
            body: jsonEncode({'review_note': ?note}),
          )
          .timeout(_writeTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final message = data['message'] as String?;
        return ModerationResult.ok(
          message ?? (action == 'approve' ? 'Đã duyệt đề xuất.' : 'Đã từ chối đề xuất.'),
        );
      }
      return ModerationResult.fail(
        _moderationError(res.statusCode, res.body),
      );
    } catch (_) {
      return ModerationResult.fail('Không kết nối được máy chủ.');
    }
  }

  /// Thông báo lỗi thân thiện cho các mã HTTP của hàng kiểm duyệt.
  static String _moderationError(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Token kiểm duyệt không đúng hoặc đã hết hạn.';
    }
    if (statusCode == 404) {
      return 'Đề xuất này không còn tồn tại.';
    }
    return _firstError(body) ?? 'Máy chủ từ chối (HTTP $statusCode).';
  }

  static String? _firstError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final errors = data['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = (errors.values.first as List).first;
        return first.toString();
      }
      return data['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class SubmitResult {
  const SubmitResult._(this.ok, this.message, this.id);

  factory SubmitResult.ok(String message, {String? id}) =>
      SubmitResult._(true, message, id);

  factory SubmitResult.fail(String message) =>
      SubmitResult._(false, message, null);

  final bool ok;
  final String message;

  /// Mã đề xuất server trả về (hằng `c_...`) để người gửi theo dõi hàng kiểm duyệt.
  final String? id;
}

/// Kết quả một lần tải hàng chờ kiểm duyệt.
class ContributionsResult {
  const ContributionsResult._(this.items, this.error, this.hasMore);

  factory ContributionsResult.ok(List<Contribution> items, {bool hasMore = false}) =>
      ContributionsResult._(items, null, hasMore);

  factory ContributionsResult.error(String message) =>
      ContributionsResult._(const [], message, false);

  final List<Contribution> items;
  final String? error;
  final bool hasMore;

  bool get ok => error == null;
}

/// Kết quả duyệt / từ chối một đề xuất.
class ModerationResult {
  const ModerationResult._(this.ok, this.message);

  factory ModerationResult.ok(String message) => ModerationResult._(true, message);

  factory ModerationResult.fail(String message) => ModerationResult._(false, message);

  final bool ok;
  final String message;
}
