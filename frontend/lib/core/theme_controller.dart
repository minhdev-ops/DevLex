import 'package:flutter/material.dart';

import '../data/local/glossary_database.dart';

/// Lưu lựa chọn giao diện (Sáng / Tối / Theo hệ thống) vào bảng sync_meta.
/// Đọc bất đồng bộ sau khi app đã dựng để không làm chậm cold start.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await GlossaryDatabase.instance.getMeta(_key);
      final parsed = _parse(raw);
      if (parsed != _mode) {
        _mode = parsed;
        notifyListeners();
      }
    } catch (_) {
      // DB chưa sẵn sàng: giữ giao diện theo hệ thống, không chặn app.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await GlossaryDatabase.instance.setMeta(_key, mode.name);
    } catch (_) {
      // Không lưu được cũng không làm hỏng trải nghiệm hiện tại.
    }
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
