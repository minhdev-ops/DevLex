import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/consent.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/home/home_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Thanh điều hướng dưới phải hiện ở mọi màn hình, kể cả khi người dùng mở
/// chi tiết thuật ngữ hay cài đặt — trước đây các màn đẩy lên che mất thanh này.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('home_shell_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
    await GlossaryDatabase.instance.setMeta(Consent.metaKey, 'true');
    await Consent.instance.load();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('thanh điều hướng vẫn hiện khi mở màn chi tiết trong tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();
    // IndexedStack dựng cả 5 tab: cho truy vấn SQLite của tab Đóng góp kịp
    // hoàn tất trong thời gian thật để không còn timer treo.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);

    final tabNavigator = tester.state<NavigatorState>(
      find
          .descendant(
            of: find.byType(HomeShell),
            matching: find.byType(Navigator),
          )
          .first,
    );
    tabNavigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('CHI TIẾT'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHI TIẾT'), findsOneWidget);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'màn đẩy lên không được che thanh điều hướng',
    );
  });

  testWidgets('bấm lại tab đang mở thì quay về màn gốc của tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    final tabNavigator = tester.state<NavigatorState>(
      find
          .descendant(
            of: find.byType(HomeShell),
            matching: find.byType(Navigator),
          )
          .first,
    );
    tabNavigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('CHI TIẾT'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT'), findsOneWidget);

    await tester.tap(find.text('Tra cứu'));
    await tester.pumpAndSettle();

    expect(find.text('CHI TIẾT'), findsNothing);
  });
}
