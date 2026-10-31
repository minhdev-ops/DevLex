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

  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = await GlossaryDatabase.instance.getMeta(metaKey);
      accepted.value = saved == 'true';
    } catch (_) {
      // Chưa mở được DB: coi như chưa đồng ý, banner sẽ hỏi lại sau.
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
