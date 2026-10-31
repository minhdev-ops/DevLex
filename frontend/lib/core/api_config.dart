import 'package:flutter/foundation.dart';

import '../data/local/glossary_database.dart';

/// Địa chỉ backend mà app gọi khi đồng bộ / gửi đóng góp.
///
/// Mặc định phụ thuộc nền tảng (Android emulator dùng 10.0.2.2, còn lại dùng
/// localhost) và có thể ghi đè lúc build bằng --dart-define=API_BASE_URL=...
/// hoặc đổi ngay trong app ở màn Cài đặt (lưu vào sync_meta).
class ApiConfig {
  ApiConfig._();

  static final ApiConfig instance = ApiConfig._();

  static const String metaKey = 'api_base_url';

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Giá trị mặc định khi người dùng chưa cấu hình gì.
  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 là alias của host từ trong Android emulator.
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Địa chỉ đang dùng; UI lắng nghe để cập nhật ngay khi người dùng đổi.
  final ValueNotifier<String> baseUrl = ValueNotifier<String>(defaultBaseUrl);

  bool _loaded = false;

  /// Đọc cấu hình đã lưu; gọi một lần lúc khởi động (sau khi mở DB).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = await GlossaryDatabase.instance.getMeta(metaKey);
      final parsed = parse(saved);
      if (parsed != null) baseUrl.value = parsed;
    } catch (_) {
      // Chưa mở được DB: giữ mặc định, app vẫn chạy offline bình thường.
    }
  }

  /// Lưu địa chỉ mới; trả về null nếu hợp lệ, ngược lại là thông báo lỗi.
  Future<String?> save(String raw) async {
    final parsed = parse(raw);
    if (parsed == null) {
      return 'Địa chỉ phải bắt đầu bằng http:// hoặc https://';
    }
    await GlossaryDatabase.instance.setMeta(metaKey, parsed);
    baseUrl.value = parsed;
    return null;
  }

  Future<void> reset() async {
    await GlossaryDatabase.instance.setMeta(metaKey, '');
    baseUrl.value = defaultBaseUrl;
  }

  /// Chuẩn hóa URL người dùng nhập: bỏ khoảng trắng và dấu / ở cuối.
  static String? parse(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    var normalized = value;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
