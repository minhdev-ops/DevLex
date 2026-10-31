import 'package:flutter/foundation.dart';

import '../data/local/glossary_database.dart';

/// Bearer token của moderator (FR-COMM-02).
///
/// Hàng chờ đóng góp chứa tên người gửi (PII) nên backend chỉ trả về khi request
/// có token hợp lệ. App không có tài khoản đăng nhập: token do quản trị viên
/// nhập một lần trong Cài đặt và lưu vào sync_meta trên thiết bị.
class ModeratorConfig {
  ModeratorConfig._();

  static final ModeratorConfig instance = ModeratorConfig._();

  static const String metaKey = 'moderator_token';

  /// Token đang dùng; màn Kiểm duyệt lắng nghe để đổi ngay khi lưu.
  final ValueNotifier<String> token = ValueNotifier<String>('');

  bool _loaded = false;

  bool get isConfigured => token.value.isNotEmpty;

  /// Đọc token đã lưu; gọi một lần lúc khởi động (sau khi mở DB).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = await GlossaryDatabase.instance.getMeta(metaKey);
      if (saved != null && saved.trim().isNotEmpty) {
        token.value = saved.trim();
      }
    } catch (_) {
      // Chưa mở được DB: coi như chưa cấu hình, phần còn lại của app vẫn chạy.
    }
  }

  /// Lưu token mới; chuỗi rỗng nghĩa là gỡ cấu hình.
  Future<void> save(String raw) async {
    final value = raw.trim();
    await GlossaryDatabase.instance.setMeta(metaKey, value);
    token.value = value;
  }

  Future<void> clear() => save('');
}
