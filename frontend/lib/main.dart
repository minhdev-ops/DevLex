import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/api_config.dart';
import 'core/app_theme.dart';
import 'core/auto_sync.dart';
import 'core/consent.dart';
import 'core/moderator_config.dart';
import 'core/theme_controller.dart';
import 'features/home/home_shell.dart';

void main() {
  // NFR #15 (Crash Rate): bắt lỗi ngoài luồng để app không văng trắng hình.
  // đồng bộ hóa / DB lỗi sẽ được ghi log thay vì làm sập UI.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
  };

  // Ở release, thay màn hình đỏ debug bằng thông báo gọn, tránh hoảng loạn cho
  // người dùng khi một widget con dựng lỗi.
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Có lỗi hiển thị ở khu vực này. Vui lòng thử lại.'),
        ),
      ),
    );
  }

  runZonedGuarded(() => runApp(const ItGlossaryApp()), (error, stack) {
    debugPrint('[Uncaught] $error\n$stack');
  });
}

class ItGlossaryApp extends StatefulWidget {
  const ItGlossaryApp({super.key});

  @override
  State<ItGlossaryApp> createState() => _ItGlossaryAppState();
}

class _ItGlossaryAppState extends State<ItGlossaryApp> {
  final _autoSync = AutoSync();

  @override
  void initState() {
    super.initState();
    // Đọc lựa chọn Sáng/Tối và địa chỉ backend sau khi frame đầu đã dựng: cold
    // start không phải chờ mở SQLite.
    AppThemeController.instance.load();
    ApiConfig.instance.load();
    ModeratorConfig.instance.load();
    Consent.instance.load();
    _autoSync.attach();
    // Lần đầu mở app (hoặc dữ liệu đã cũ): kéo delta trong im lặng.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync.maybeSync());
  }

  @override
  void dispose() {
    _autoSync.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'IT Glossary & Roadmap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppThemeController.instance.mode,
        home: const HomeShell(),
      ),
    );
  }
}
