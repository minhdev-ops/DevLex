import '../core/fuzzy.dart';
import '../core/study_stats.dart';
import '../core/sync_normalizer.dart';
import '../core/trust.dart';
import 'api_client.dart';
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
  Map<String, List<Term>> _byConcept = const {};
  Map<String, StudyState> _study = const {};
  List<_SearchKeys> _keys = const [];
  Map<String, Term> _byAcronym = const {};
  bool _loaded = false;

  /// Ngưỡng điểm thấp nhất để một mục từ xuất hiện trong kết quả.
  static const double _minScore = 0.55;

  Future<void> warmUp() async {
    if (_loaded) return;
    _terms = await GlossaryDatabase.instance.loadAllTerms();
    _aliases = await GlossaryDatabase.instance.loadAliases();
    _study = await GlossaryDatabase.instance.allStudyStates();
    _byId = {for (final t in _terms) t.id: t};
    final byConcept = <String, List<Term>>{};
    for (final t in _terms) {
      final key = t.concept;
      if (key == null || key.isEmpty) continue;
      byConcept.putIfAbsent(key, () => []).add(t);
    }
    _byConcept = byConcept;
    _indexKeys();
    _loaded = true;
  }

  /// Chuẩn hóa khóa tìm kiếm một lần cho mỗi mục từ thay vì mỗi lần gõ: với kho
  /// >6.000 dòng, chi phí normalize và đếm ký tự theo từng query là phần chậm nhất.
  void _indexKeys() {
    _keys = [
      for (final t in _terms)
        _SearchKeys(
          profileOf(normalizeQuery(t.acronym)),
          profileOf(normalizeQuery(t.fullNameEn)),
          profileOf(normalizeQuery(t.fullNameVi)),
        ),
    ];
    final byAcronym = <String, Term>{};
    for (var i = 0; i < _terms.length; i++) {
      byAcronym.putIfAbsent(_keys[i].acronym.text, () => _terms[i]);
    }
    _byAcronym = byAcronym;
  }

  ApiClient? _api;

  /// Guard: 500 dòng/lô * 200 lô = 100k bản ghi, đủ cho toàn bộ khối từ điển.
  static const int _maxSyncPages = 200;

  /// Delta Sync (SRS §5 / #9): kéo các term thay đổi từ server về SQLite cục bộ,
  /// cập nhật con trỏ last_pulled_at, rồi nạp lại cache in-memory.
  /// Server trả theo lô nên phải lặp cho tới khi hết `next_cursor`.
  Future<SyncOutcome> syncNow({ApiClient? api}) async {
    final client = api ?? _api ?? (_api = ApiClient());
    final since = await GlossaryDatabase.instance.getSyncCursor();

    var updated = 0;
    var deleted = 0;
    var serverTimestamp = 0;
    String? pageCursor;

    for (var page = 0; page < _maxSyncPages; page++) {
      final payload = await client.syncDelta(since, cursor: pageCursor);
      if (payload == null) {
        // Mất mạng giữa chừng: các lô đã ghi vẫn còn nguyên (upsert idempotent),
        // con trỏ chưa dịch nên lần sau kéo lại từ đầu.
        return page == 0 ? SyncOutcome.failed() : _done(updated, deleted, 0);
      }

      final result = SyncNormalizer.normalize(payload);
      final terms = result.rows.map(Term.fromJson).toList();
      if (terms.isNotEmpty) {
        updated += await GlossaryDatabase.instance.upsertTerms(terms);
      }
      if (result.deletedIds.isNotEmpty) {
        await GlossaryDatabase.instance.deleteTerms(result.deletedIds);
        deleted += result.deletedIds.length;
      }
      // Mốc của lô ĐẦU tiên: các lô sau có updated_at lớn hơn, lấy mốc sau sẽ
      // bỏ sót bản ghi sửa đổi xen giữa hai lô.
      if (page == 0) serverTimestamp = result.serverTimestamp;

      if (!result.hasMore || result.nextCursor == null) {
        return _done(updated, deleted, serverTimestamp);
      }
      pageCursor = result.nextCursor;
    }

    // hết @_maxSyncPages mà server vẫn còn lô -> chưa sync xong, giữ con trỏ cũ
    // để lần sau kéo tiếp từ đầu, không bỏ sót bản ghi.
    return _done(updated, deleted, 0);
  }

  Future<SyncOutcome> _done(int updated, int deleted, int serverTimestamp) async {
    if (serverTimestamp > 0) {
      await GlossaryDatabase.instance.setSyncCursor(serverTimestamp);
    }

    _loaded = false;
    await warmUp();

    return SyncOutcome(
      ok: true,
      updated: updated,
      deleted: deleted,
      serverTimestamp: serverTimestamp,
    );
  }

  Term? termById(String id) => _byId[id];

  /// Cùng khái niệm nhưng mỗi nguồn một ngữ cảnh (SRS mục 4, issue #8 giai đoạn 2).
  /// Gom offline theo khóa `concept` mà delta sync mang về — không cần request thêm.
  ConceptTrust trustFor(Term term) {
    final key = term.concept;
    final group = (key == null || key.isEmpty) ? const <Term>[] : (_byConcept[key] ?? const <Term>[]);
    final contexts = group.where((t) => t.id != term.id).toList(growable: false);

    final sources = <String>{
      for (final a in term.attribution) a.source,
      for (final t in contexts)
        if (t.attribution.isNotEmpty) t.attribution.first.source,
    }.where((s) => s.isNotEmpty).toList(growable: false);

    final own = term.attribution.isEmpty ? null : term.attribution.first.confidence;

    return ConceptTrust(
      contexts: contexts,
      agreeingSources: sources,
      confidence: corroboratedConfidence(own ?? 50, sources.length),
    );
  }

  /// Instant search (<50ms) + fuzzy + acronym alias mapping, offline.
  List<SearchResult> search(String query, {int limit = 20}) {
    final needle = normalizeQuery(query);
    if (needle.isEmpty) return const [];

    final needleProfile = profileOf(needle);
    final alias = _aliases[needle];
    final scored = <SearchResult>[];

    for (var i = 0; i < _terms.length; i++) {
      final term = _terms[i];
      final keys = _keys[i];
      var best = 0.0;
      for (final field in [keys.acronym, keys.en, keys.vi]) {
        final s = similarityProfiled(needleProfile, field, cutoff: _minScore);
        if (s > best) best = s;
        if (best >= 1) break;
      }

      final isAlias = alias != null && alias.termId == term.id;
      if (isAlias && best < 1) {
        best = 1;
      }
      if (best >= _minScore) {
        scored.add(SearchResult(
          term: term,
          similarity: best,
          matchedAlias: isAlias ? alias : null,
        ));
      }
    }

    scored.sort((a, b) => b.similarity.compareTo(a.similarity));
    return _collapseByConcept(scored).take(limit).toList();
  }

  /// Hai dòng cùng `concept` là một khái niệm nhiều nguồn chứ không phải hai kết quả
  /// khác nhau: giữ lại một dòng (ưu tiên bản đã có tên tiếng Việt) và đếm số nguồn gộp.
  List<SearchResult> _collapseByConcept(List<SearchResult> ordered) {
    final out = <SearchResult>[];
    final slotOf = <String, int>{};

    for (final r in ordered) {
      final key = r.term.concept;
      if (key == null || key.isEmpty) {
        out.add(r);
        continue;
      }

      final slot = slotOf[key];
      if (slot == null) {
        slotOf[key] = out.length;
        out.add(r);
        continue;
      }

      final kept = out[slot];
      final preferIncoming = kept.term.needsTranslation && !r.term.needsTranslation;
      final winner = preferIncoming ? r : kept;
      out[slot] = winner.withSiblings(winner.siblingCount + 1);
    }

    return out;
  }

  /// Gợi ý cho Context Decoder-style highlight: acronym khớp chính xác trong văn bản.
  Term? findByAcronymExact(String token) {
    final normalized = normalizeQuery(token);
    final alias = _aliases[normalized];
    if (alias != null) return _byId[alias.termId];
    return _byAcronym[normalized];
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

  /// Kho đang có sẵn trên máy — cho người dùng biết mình đang tra cứu bao nhiêu mục từ.
  int get termCount => _terms.length;

  /// Số khái niệm được từ hai nguồn độc lập trở lên cùng định nghĩa (điểm tin cậy cao nhất).
  int get corroboratedConceptCount => _byConcept.values.where((l) => l.length > 1).length;

  /// Lần kéo delta sync gần nhất; null nếu chưa từng đồng bộ (dữ liệu đóng gói trong app).
  Future<DateTime?> lastSyncAt() async {
    final epoch = await GlossaryDatabase.instance.getSyncCursor();
    if (epoch == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  }

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

  /// FR-QUIZ-03: toàn bộ số liệu cho dashboard tiến trình ghi nhớ.
  StudyStats studyStats() => StudyStats.from(_study.values);
}

/// Ba khóa đã chuẩn hóa của một mục từ kèm hồ sơ ký tự, dựng một lần khi nạp kho
/// để mỗi lần gõ chỉ còn so sánh thay vì normalize lại toàn bộ danh sách.
class _SearchKeys {
  const _SearchKeys(this.acronym, this.en, this.vi);

  final CharProfile acronym;
  final CharProfile en;
  final CharProfile vi;
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

/// Kết quả một lần Delta Sync.
class SyncOutcome {
  const SyncOutcome({
    required this.ok,
    this.updated = 0,
    this.deleted = 0,
    this.serverTimestamp = 0,
  });

  const SyncOutcome.failed() : ok = false, updated = 0, deleted = 0, serverTimestamp = 0;

  final bool ok;
  final int updated;
  final int deleted;
  final int serverTimestamp;
}

/// Mức tin cậy của một khái niệm, tính offline từ các mục từ cùng `concept`.
class ConceptTrust {
  const ConceptTrust({
    required this.contexts,
    required this.agreeingSources,
    required this.confidence,
  });

  /// Các ngữ cảnh từ nguồn khác cho cùng khái niệm.
  final List<Term> contexts;

  /// Tên nguồn độc lập đã định nghĩa khái niệm này.
  final List<String> agreeingSources;

  /// Điểm đã cộng hưởng (+4 mỗi nguồn phụ, trần 100) — cùng công thức backend.
  final int confidence;
}
