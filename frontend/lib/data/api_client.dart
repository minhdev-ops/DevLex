import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client tối giản cho Backend API (Laravel, /api/v1).
/// Mặc định offline-first: chỉ dùng khi người dùng chủ động gửi lên server.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000'),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri get _endpoint => Uri.parse('$baseUrl/api/v1/contributions');

  Uri _syncEndpoint(int lastPulledAt, {String? cursor}) {
    final params = <String, String>{
      'last_pulled_at': '$lastPulledAt',
      'page_size': '500',
      'cursor': ?cursor,
    };
    return Uri.parse('$baseUrl/api/v1/sync/delta').replace(queryParameters: params);
  }

  /// Delta Sync (SRS §5): lấy các term thay đổi sau `lastPulledAt` (epoch giây).
  /// Server trả theo lô; `cursor` (next_cursor từ lô trước) lấy lô kế tiếp.
  /// Trả payload gốc (SyncNormalizer sẽ chuẩn hóa); null nếu lỗi/mất mạng.
  Future<Map<String, dynamic>?> syncDelta(int lastPulledAt, {String? cursor}) async {
    try {
      final res = await _client.get(
        _syncEndpoint(lastPulledAt, cursor: cursor),
        headers: {'Accept': 'application/json'},
      );
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
      final res = await _client.post(
        _endpoint,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final row = data['data'] as Map<String, dynamic>?;
        return SubmitResult.ok(data['message'] as String? ?? 'Đã gửi đề xuất.', id: row?['id'] as String?);
      }
      final detail = _firstError(res.body);
      return SubmitResult.fail(detail ?? 'Máy chủ từ chối (HTTP ${res.statusCode}).');
    } catch (_) {
      return SubmitResult.fail('Không kết nối được máy chủ. Đề xuất chưa được gửi.');
    }
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

  factory SubmitResult.ok(String message, {String? id}) => SubmitResult._(true, message, id);

  factory SubmitResult.fail(String message) => SubmitResult._(false, message, null);

  final bool ok;
  final String message;

  /// Mã đề xuất server trả về (hằng `c_...`) để người gửi theo dõi hàng kiểm duyệt.
  final String? id;
}
