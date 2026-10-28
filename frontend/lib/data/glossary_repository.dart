import '../core/fuzzy.dart';
import 'local/glossary_database.dart';
import 'models/term.dart';

/// SRS: chu kỳ lặp lại ngắt quãng theo SRS mục 2.4 (1 → 3 → 7 ngày).
const _srsLadder = [1, 3, 7];

int nextIntervalDays(int current) {
  if (current <= 0) return _srsLadder.first;
  final idx = _srsLadder.indexOf(current);
  if (idx < 0 || idx == _srsLadder.length - 1) return _srsLadder.last;
  return _srsLadder[idx + 1];
}

class GlossaryRepository {
  GlossaryRepository._();

  static final GlossaryRepository instance = GlossaryRepository._();

  List<Term> _terms = const [];
  Map<String, TermAlias> _aliases = const {};
  Map<String, Term> _byId = const {};
  Map<String, StudyState> _study = const {};
  bool _loaded = false;

  Future<void> warmUp() async {
    if (_loaded) return;
    _terms = await GlossaryDatabase.instance.loadAllTerms();
    _aliases = await GlossaryDatabase.instance.loadAliases();
    _study = await GlossaryDatabase.instance.allStudyStates();
    _byId = {for (final t in _terms) t.id: t};
    _loaded = true;
  }

  Term? termById(String id) => _byId[id];

  /// Instant search (<50ms) + fuzzy + acronym alias mapping, offline.
  List<SearchResult> search(String query, {int limit = 20}) {
    final needle = normalizeQuery(query);
    if (needle.isEmpty) return const [];

    final alias = _aliases[needle];
    final scored = <SearchResult>[];

    for (final term in _terms) {
      var best = 0.0;
      for (final field in [term.acronym, term.fullNameEn]) {
        final s = similarity(needle, normalizeQuery(field));
        if (s > best) best = s;
      }
      final viScore = similarity(needle, normalizeQuery(term.fullNameVi));
      if (viScore > best) best = viScore;

      if (alias != null && alias.termId == term.id && best < 1) {
        best = 1;
      }
      if (best >= 0.55) {
        scored.add(SearchResult(
          term: term,
          similarity: best,
          matchedAlias: alias != null && alias.termId == term.id ? alias : null,
        ));
      }
    }

    scored.sort((a, b) => b.similarity.compareTo(a.similarity));
    return scored.take(limit).toList();
  }

  /// Gợi ý cho Context Decoder-style highlight: acronym khớp chính xác trong văn bản.
  Term? findByAcronymExact(String token) {
    final normalized = normalizeQuery(token);
    final alias = _aliases[normalized];
    if (alias != null) return _byId[alias.termId];
    for (final t in _terms) {
      if (normalizeQuery(t.acronym) == normalized) return t;
    }
    return null;
  }

  static const careers = <String, String>{
    'frontend': 'Frontend Developer',
    'backend': 'Backend Developer',
    'devops': 'DevOps Engineer',
    'project_comm': 'Project Communication',
  };

  List<Term> termsByCareer(String career) =>
      _terms.where((t) => t.career == career).toList(growable: false);

  StudyState cachedStudyState(String termId) => _study[termId] ?? StudyState.empty;

  Map<String, StudyState> get allStudyStates => _study;

  /// Tỷ lệ % hoàn thành một lộ trình nghề nghiệp (FR-MAP-03).
  Future<int> careerProgress(String career) =>
      GlossaryDatabase.instance.progressPercent(career);

  /// FR-MAP-03: đánh dấu Đã học / Cần ôn tập cho một thuật ngữ.
  Future<int> toggleLearned(String termId) async {
    final current = _study[termId] ?? StudyState.empty;
    final nowLearned = !current.learned;
    await GlossaryDatabase.instance.saveStudyState(
      termId: termId,
      learned: nowLearned,
      intervalDays: current.intervalDays,
      dueDate: current.dueDate,
      streak: current.streak,
    );
    _study[termId] = StudyState(
      termId: termId,
      learned: nowLearned,
      intervalDays: current.intervalDays,
      dueDate: current.dueDate,
      streak: current.streak,
    );
    return GlossaryDatabase.instance.progressPercent(
        _byId[termId]?.career ?? '');
  }

  /// FR-QUIZ-02: ôn flashcard -> tính chu kỳ lặp lại tiếp theo (1/3/7 ngày) + streak.
  Future<StudyState> reviewFlashcard(String termId, {required bool remembered}) async {
    final current = _study[termId] ?? StudyState.empty;
    final interval = remembered
        ? nextIntervalDays(current.intervalDays)
        : 1;
    final streak = remembered ? current.streak + 1 : 0;
    final due = DateTime.now().add(Duration(days: interval)).toUtc().toIso8601String();

    await GlossaryDatabase.instance.saveStudyState(
      termId: termId,
      learned: current.learned || remembered,
      intervalDays: interval,
      dueDate: due,
      streak: streak,
    );

    final next = StudyState(
      termId: termId,
      learned: current.learned || remembered,
      intervalDays: interval,
      dueDate: due,
      streak: streak,
    );
    _study[termId] = next;
    return next;
  }

  /// Hàng chờ ôn tập: thẻ quá hạn hôm nay, ưu tiên streak cao hơn.
  List<Term> dueFlashcards() {
    final now = DateTime.now().toUtc();
    final due = _study.values
        .where((s) => s.dueDate != null && DateTime.parse(s.dueDate!).isBefore(now))
        .toList()
      ..sort((a, b) => b.streak.compareTo(a.streak));
    return due.map((s) => _byId[s.termId]).whereType<Term>().toList();
  }

  /// FR-QUIZ-01: sinh bộ câu hỏi trắc nghiệm từ các thuật ngữ đã học/xem.
  /// Trả về rỗng nếu người dùng có < 5 thuật ngữ (điều kiện tiên quyết SRS).
  List<QuizQuestion> buildQuiz({int size = 5}) {
    final pool = _study.keys
        .map((id) => _byId[id])
        .whereType<Term>()
        .toList();
    if (pool.length < 5) return const [];

    pool.shuffle();
    final questions = <QuizQuestion>[];
    for (final correct in pool.take(size)) {
      final distractors = pool.where((t) => t.id != correct.id).toList()
        ..shuffle();
      final options = [
        correct.shortDefinition,
        ...distractors.take(3).map((t) => t.shortDefinition),
      ]..shuffle();
      questions.add(QuizQuestion(
        term: correct,
        options: options,
        correctIndex: options.indexOf(correct.shortDefinition),
      ));
    }
    return questions;
  }

  /// FR-QUIZ-03: số ngày ôn tập liên tục gần nhất (streak tổng).
  int totalReviewStreak() =>
      _study.values.fold(0, (max, s) => s.streak > max ? s.streak : max);
}

class QuizQuestion {
  const QuizQuestion({
    required this.term,
    required this.options,
    required this.correctIndex,
  });

  final Term term;
  final List<String> options;
  final int correctIndex;
}
