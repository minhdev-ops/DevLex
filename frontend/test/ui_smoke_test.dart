import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/app_theme.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/decoder/decoder_screen.dart';
import 'package:it_glossary/features/quiz/quiz_screen.dart';
import 'package:it_glossary/features/roadmap/roadmap_screen.dart';
import 'package:it_glossary/features/search/search_screen.dart';
import 'package:it_glossary/features/settings/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Smoke test trên kích thước điện thoại nhỏ: bắt lỗi tràn layout ở các màn
/// chính mà unit test logic không nhìn thấy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('ui_smoke_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> pumpPhone(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard tra cứu hiển thị trên màn hình hẹp', (tester) async {
    await pumpPhone(tester, const SearchScreen());

    expect(find.text('DevLex'), findsOneWidget);
    expect(find.text('Lộ trình nghề nghiệp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sơ đồ lộ trình hiển thị trên màn hình hẹp', (tester) async {
    await pumpPhone(tester, const RoadmapScreen());

    expect(find.text('Sơ đồ lộ trình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('giải mã ngữ cảnh hiển thị trên màn hình hẹp', (tester) async {
    await pumpPhone(tester, const DecoderScreen());

    expect(find.text('Giải mã ngữ cảnh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ôn tập hiển thị trên màn hình hẹp', (tester) async {
    await pumpPhone(tester, const QuizScreen());

    expect(find.text('Ôn tập Flashcard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cài đặt hiển thị trên màn hình hẹp', (tester) async {
    await pumpPhone(tester, const SettingsScreen());

    expect(find.text('Cài đặt & giới thiệu'), findsOneWidget);
    expect(find.text('Máy chủ đồng bộ'), findsOneWidget);

    // Phần nguồn dữ liệu nằm dưới màn hình đầu tiên -> phải cuộn tới.
    await tester.scrollUntilVisible(
      find.text('Nguồn dữ liệu & bản quyền'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nguồn dữ liệu & bản quyền'), findsOneWidget);
    final error = tester.takeException();
    if (error != null) debugPrint(error.toString());
    expect(error, isNull);
  });
}
