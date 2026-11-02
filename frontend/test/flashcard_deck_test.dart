import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/app_theme.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/quiz/quiz_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Màn Ôn tập trước đây chỉ lấy thẻ đã quá hạn nên người mới thấy trống và
/// không có cách làm lại từ đã học. Bộ thẻ mới phải luôn có việc để làm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('flashcard_deck');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  setUp(() async {
    // Mỗi test bắt đầu như người mới: chưa có tiến độ học nào.
    await GlossaryRepository.instance.resetProgress();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  test('người mới mở app vẫn có thẻ để học', () {
    final deck = GlossaryRepository.instance.flashcardDeck(
      FlashcardScope.all,
    );

    expect(deck, isNotEmpty, reason: 'chưa học gì thì phải có từ mới');
    expect(deck.length, lessThanOrEqualTo(30));
  });

  test('thẻ đã chấm chuyển sang mục Đã học và rời khỏi Từ mới', () async {
    final repo = GlossaryRepository.instance;
    final fresh = repo.flashcardDeck(FlashcardScope.fresh, limit: 5);
    expect(fresh, isNotEmpty);

    final term = fresh.first;
    await repo.reviewFlashcard(term.id, remembered: true);

    expect(
      repo.flashcardDeck(FlashcardScope.learned, limit: 100000).map((t) => t.id),
      contains(term.id),
    );
    expect(
      repo.flashcardDeck(FlashcardScope.fresh, limit: 100000).map((t) => t.id),
      isNot(contains(term.id)),
    );
  });

  test('số lượng trên từng chip khớp với bộ thẻ', () {
    final repo = GlossaryRepository.instance;
    final counts = repo.flashcardCounts();

    expect(counts.keys.toSet(), FlashcardScope.values.toSet());
    expect(
      counts[FlashcardScope.fresh],
      repo.flashcardDeck(FlashcardScope.fresh, limit: 100000).length,
    );
    expect(
      counts[FlashcardScope.all]!,
      greaterThanOrEqualTo(counts[FlashcardScope.fresh]!),
    );
  });

  testWidgets('màn Ôn tập mở ra đã có thẻ và có chip chọn phạm vi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const QuizScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Thẻ 1/'), findsOneWidget);
    expect(find.textContaining('Từ mới'), findsOneWidget);
    expect(find.text('Lật thẻ'), findsOneWidget);
  });
}
