import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/app_theme.dart';
import 'package:it_glossary/data/career_tracks.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/roadmap/roadmap_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phần lớn mục từ quét từ nguồn không gắn trường career, nên lộ trình phải
/// chọn thuật ngữ theo từ khóa/chủ đề (hoặc theo stages đã biên soạn) thay vì
/// chỉ đọc trường đó.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('career_tracks');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  test('có nhiều lộ trình và lộ trình nào cũng có thuật ngữ', () {
    final repo = GlossaryRepository.instance;

    expect(GlossaryRepository.careers.length, greaterThanOrEqualTo(10));
    for (final entry in GlossaryRepository.careers.entries) {
      final terms = repo.termsByCareer(entry.key);
      expect(
        terms.length,
        greaterThanOrEqualTo(5),
        reason: 'lộ trình ${entry.key} quá ít nút để vẽ sơ đồ',
      );
      expect(
        terms.length,
        lessThanOrEqualTo(60),
        reason: 'lộ trình ${entry.key} quá nhiều nút, sơ đồ sẽ rối',
      );
    }
  });

  test('mỗi sơ đồ không có hai nút trùng nhau', () {
    final repo = GlossaryRepository.instance;
    for (final key in GlossaryRepository.careers.keys) {
      final terms = repo.termsByCareer(key);
      final ids = terms.map((t) => t.id).toSet();
      final acronyms = terms.map((t) => t.acronym.toLowerCase()).toSet();
      expect(ids.length, terms.length, reason: 'trùng id ở $key');
      expect(acronyms.length, terms.length, reason: 'trùng tên ở $key');
    }
  });

  test('lộ trình chia nhóm để bộ chọn không bị dài', () {
    expect(careerGroups.length, greaterThanOrEqualTo(3));
    final total = careerGroups.values.fold<int>(0, (n, g) => n + g.length);
    expect(total, careerTracks.length);
  });

  testWidgets('đổi lộ trình qua bộ chọn nhóm', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const RoadmapScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Frontend Developer'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn lộ trình nghề nghiệp'), findsOneWidget);

    await tester.tap(find.text('Backend Developer').last);
    await tester.pumpAndSettle();

    expect(find.text('Backend Developer'), findsWidgets);
    expect(find.text('Chọn lộ trình nghề nghiệp'), findsNothing);
  });
}
