import 'package:flutter/foundation.dart';

import '../data/local/glossary_database.dart';

/// Trạng thái đồng ý chính sách quyền riêng tư (Google Play: Privacy Policy).
///
/// App không có tài khoản và không thu thập PII, nhưng Play yêu cầu người dùng
/// được thông báo rõ trước khi dùng. Cờ đồng ý lưu trong sync_meta nên chỉ hỏi
/// một lần cho mỗi phiên bản chính sách.
class Consent {
  Consent._();

  static final Consent instance = Consent._();

  /// Đổi hậu tố khi nội dung chính sách thay đổi để hỏi lại người dùng.
  static const String metaKey = 'privacy_consent_v1';

  final ValueNotifier<bool> accepted = ValueNotifier<bool>(false);

  /// Future của lần đọc đang chạy. Nhiều nơi gọi [load] cùng lúc (main và
  /// HomeShell) phải chờ chung một lần đọc, nếu không bên gọi sau sẽ thấy
  /// accepted == false lúc DB còn đang mở và hỏi lại người dùng mỗi cold start.
  Future<void>? _pending;

  bool get isLoaded => _pending != null;

  Future<void> load() {
    final pending = _pending;
    if (pending != null) return pending;
    final future = _read();
    _pending = future;
    return future;
  }

  Future<void> _read() async {
    try {
      final saved = await GlossaryDatabase.instance.getMeta(metaKey);
      accepted.value = saved == 'true';
    } catch (_) {
      // Chưa mở được DB: coi như chưa đồng ý và cho phép lần gọi sau thử lại.
      _pending = null;
    }
  }

  Future<void> accept() async {
    await GlossaryDatabase.instance.setMeta(metaKey, 'true');
    accepted.value = true;
  }

  /// Dùng cho test hoặc khi cần hỏi lại (đổi phiên bản chính sách).
  Future<void> reset() async {
    await GlossaryDatabase.instance.setMeta(metaKey, '');
    accepted.value = false;
  }
}
