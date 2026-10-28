import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
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

class ItGlossaryApp extends StatelessWidget {
  const ItGlossaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IT Glossary & Roadmap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}
