import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/detail/term_detail_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Đảm bảo Tầng 2 (Bối cảnh & Trực quan) luôn được vẽ cho người dùng: thẻ
/// Tầng 2 và sơ đồ luồng (có mũi tên nối các thuật ngữ) phải hiện diện.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('term_detail_tier2_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('Tang 2 va so do luong luon hien thi cho thuat ngu co quan he', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TermDetailScreen(termId: 'dx_react')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('TẦNG 2 — BỐI CẢNH & TRỰC QUAN'),
      findsWidgets,
      reason: 'Nguoi dung phai luon thay duoc Tang 2',
    );

    expect(
      find.text('Sơ đồ luồng hoạt động (tóm tắt)'),
      findsWidgets,
      reason: 'Tang 2 can mot so do truc quan, khong chi van ban',
    );

    expect(find.text('Next.js'), findsWidgets);
    expect(find.text('Virtual DOM'), findsWidgets);
  });

  testWidgets('Tang 2 van hien thi voi thuat ngu co doan ###', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TermDetailScreen(termId: 'term_k8s_001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('TẦNG 2 — BỐI CẢNH & TRỰC QUAN'), findsWidgets);
    expect(find.text('Sơ đồ luồng hoạt động (tóm tắt)'), findsWidgets);
  });
}
