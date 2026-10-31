import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  final repo = GlossaryRepository.instance;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('learning_flow_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await repo.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  // Dashboard và tab Ôn tập nằm trong IndexedStack nên chỉ build một lần; nếu
  // không có tín hiệu này thì tiến độ hiển thị sẽ cũ sau khi học ở tab khác.
  test('mọi thay đổi tiến độ đều phát tín hiệu cho UI', () async {
    final id = repo.termsByCareer('backend').first.id;
    final before = repo.progressRevision.value;

    await repo.recordView(id);
    expect(repo.progressRevision.value, greaterThan(before));

    final afterView = repo.progressRevision.value;
    await repo.toggleLearned(id);
    expect(repo.progressRevision.value, greaterThan(afterView));

    final afterToggle = repo.progressRevision.value;
    await repo.reviewFlashcard(id, remembered: false);
    expect(repo.progressRevision.value, greaterThan(afterToggle));

    final afterReview = repo.progressRevision.value;
    await repo.resetProgress();
    expect(repo.progressRevision.value, greaterThan(afterReview));
  });

  test('lộ trình gộp bản trùng khái niệm và ánh xạ lại liên kết', () {
    final devops = repo.termsByCareer('devops');
    expect(devops.where((t) => t.acronym == 'Kubernetes').length, 1);
    expect(devops.where((t) => t.acronym == 'IaaS').length, 1);
    expect(
      devops.any(
        (t) =>
            t.prerequisites.contains('cn_kubernetes') ||
            t.relatedTerms.contains('cn_kubernetes'),
      ),
      isFalse,
      reason: 'cạnh phải trỏ tới id của bản đã được giữ lại',
    );
  });

  test(
    'mở thuật ngữ ghi nhận đã xem và đủ 5 mục thì sinh được trắc nghiệm',
    () async {
      for (final id in [
        'term_api_001',
        'term_jwt_008',
        'term_docker_020',
        'term_k8s_001',
        'term_rest_010',
      ]) {
        await repo.recordView(id);
      }

      expect(repo.recentTerms().length, greaterThanOrEqualTo(5));

      final quiz = repo.buildQuiz();
      expect(quiz.length, inInclusiveRange(5, 10));
      for (final q in quiz) {
        expect(q.options.length, greaterThanOrEqualTo(2));
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
        expect(q.prompt, isNotEmpty);
        expect(q.options[q.correctIndex], isNotEmpty);
      }
    },
  );

  test('đánh dấu đã học đưa thẻ vào hàng chờ ôn ngay', () async {
    await repo.toggleLearned('term_rest_010');

    final state = repo.cachedStudyState('term_rest_010');
    expect(state.learned, isTrue);
    expect(state.dueDate, isNotNull);
    expect(
      repo.dueFlashcards().any((t) => t.id == 'term_rest_010'),
      isTrue,
      reason: 'SRS 1 → 3 → 7 ngày phải bắt đầu ngay sau khi đánh dấu',
    );
  });

  test('chưa nhớ chuyển sang Cần ôn tập và hẹn lại 1 ngày', () async {
    await repo.reviewFlashcard('term_rest_010', remembered: false);

    final state = repo.cachedStudyState('term_rest_010');
    expect(state.learned, isFalse);
    expect(state.needsReview, isTrue);
    expect(state.intervalDays, 1);
    expect(repo.careerProgressSync('backend'), greaterThanOrEqualTo(0));
  });

  test('tiến độ lộ trình cập nhật tức thì từ cache', () async {
    final before = repo.careerProgressSync('devops');
    await repo.toggleLearned('term_k8s_001');
    expect(repo.careerProgressSync('devops'), greaterThan(before));
  });
}
