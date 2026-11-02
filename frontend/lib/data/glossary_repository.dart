import 'package:flutter/foundation.dart';

import '../core/fuzzy.dart';
import '../core/study_stats.dart';
import 'career_tracks.dart';
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

/// Phạm vi thẻ của một phiên ôn tập.
enum FlashcardScope {
  /// Thẻ đã tới hạn ôn theo chu kỳ 1 → 3 → 7 ngày.
  due,

  /// Thuật ngữ chưa từng học.
  fresh,

  /// Toàn bộ thuật ngữ đã học — dùng khi muốn làm lại.
  learned,

  /// Trộn thẻ đến hạn và thẻ mới (mặc định).
  all,
}

class GlossaryRepository {
  GlossaryRepository._();

  static final GlossaryRepository instance = GlossaryRepository._();

  List<Term> _terms = const [];

  /// Cache theo lộ trình: dashboard và màn Lộ trình gọi lại rất nhiều lần, mỗi
  /// lần quét 6.5k thuật ngữ sẽ làm cuộn bị giật. Xóa khi kho dữ liệu đổi.
  final _careerCache = <String, List<Term>>{};
  Map<String, TermAlias> _aliases = const {};
  Map<String, Term> _byId = const {};
  Map<String, List<Term>> _byConcept = const {};
  Map<String, StudyState> _study = const {};
  List<_SearchKeys> _keys = const [];
  Map<String, Term> _byAcronym = const {};
  bool _loaded = false;

  /// Ngưỡng điểm thấp nhất để một mục từ xuất hiện trong kết quả.
  static const double _minScore = 0.55;

  /// Bumped mỗi khi tiến độ học đổi (đánh dấu, ôn tập, xem, đặt lại).
  ///
  /// Các tab nằm trong IndexedStack chỉ build một lần, nên nếu không có tín
  /// hiệu này thì dashboard/Ôn tập vẫn hiển thị số liệu cũ sau khi người dùng
  /// học ở tab khác.
  final ValueNotifier<int> progressRevision = ValueNotifier<int>(0);

  void _bumpProgress() => progressRevision.value++;

  Future<void> warmUp() async {
    if (_loaded) return;
    _careerCache.clear();
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
        return page == 0
            ? SyncOutcome.failed()
            : _done(updated, deleted, 0, partial: true);
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
    return _done(updated, deleted, 0, partial: true);
  }

  Future<SyncOutcome> _done(
    int updated,
    int deleted,
    int serverTimestamp, {
    bool partial = false,
  }) async {
    if (serverTimestamp > 0) {
      await GlossaryDatabase.instance.setSyncCursor(serverTimestamp);
    }

    _loaded = false;
    await warmUp();
    _bumpProgress();

    return SyncOutcome(
      ok: true,
      updated: updated,
      deleted: deleted,
      serverTimestamp: serverTimestamp,
      partial: partial,
    );
  }

  Term? termById(String id) => _byId[id];

  /// Cùng khái niệm nhưng mỗi nguồn một ngữ cảnh (SRS mục 4, issue #8 giai đoạn 2).
  /// Gom offline theo khóa `concept` mà delta sync mang về — không cần request thêm.
  ConceptTrust trustFor(Term term) {
    final key = term.concept;
    final group = (key == null || key.isEmpty)
        ? const <Term>[]
        : (_byConcept[key] ?? const <Term>[]);
    final contexts = group
        .where((t) => t.id != term.id)
        .toList(growable: false);

    final sources = <String>{
      for (final a in term.attribution) a.source,
      for (final t in contexts)
        if (t.attribution.isNotEmpty) t.attribution.first.source,
    }.where((s) => s.isNotEmpty).toList(growable: false);

    final own = term.attribution.isEmpty
        ? null
        : term.attribution.first.confidence;

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
        scored.add(
          SearchResult(
            term: term,
            similarity: best,
            matchedAlias: isAlias ? alias : null,
          ),
        );
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
      final preferIncoming =
          kept.term.needsTranslation && !r.term.needsTranslation;
      final winner = preferIncoming ? r : kept;
      // Đổi sang dòng mới thì phải mang theo số anh em đã gộp trước đó, nếu không
      // bản có tên tiếng Việt thắng sẽ báo thiếu nguồn.
      out[slot] = winner.withSiblings(kept.siblingCount + r.siblingCount + 1);
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

  /// Nhãn lộ trình theo key — sinh từ bảng [careerTracks] để thêm nghề mới chỉ
  /// cần sửa một chỗ.
  static final careers = <String, String>{
    for (final track in careerTracks) track.key: track.label,
  };

  static CareerTrack? trackOf(String key) {
    for (final track in careerTracks) {
      if (track.key == key) return track;
    }
    return null;
  }

  /// Thuật ngữ của một lộ trình, đã gộp các bản trùng khái niệm (ví dụ CNCF
  /// Kubernetes + bản biên soạn tiếng Việt) thành một nút duy nhất.
  ///
  /// Liên kết tiên quyết/liên quan được ánh xạ sang id của bản thắng để sơ đồ
  /// không còn cạnh trỏ tới nút đã bị ẩn.
  List<Term> termsByCareer(String career) {
    final cached = _careerCache[career];
    if (cached != null) return cached;
    final groups = _careerGroups(career);
    final winnerOf = <String, Term>{};
    final remap = <String, String>{};
    for (final entry in groups.entries) {
      final winner = entry.value.reduce((a, b) => _preferTerm(a, b) ? a : b);
      winnerOf[entry.key] = winner;
      for (final t in entry.value) {
        remap[t.id] = winner.id;
      }
    }

    List<String> clean(Iterable<String> ids, String winnerId) {
      final seen = <String>{};
      final out = <String>[];
      for (final id in ids) {
        final mapped = remap[id] ?? id;
        if (mapped != winnerId && seen.add(mapped)) out.add(mapped);
      }
      return out;
    }

    final out = <Term>[];
    for (final entry in groups.entries) {
      final winner = winnerOf[entry.key]!;
      out.add(
        winner.copyWith(
          prerequisites: clean(winner.prerequisites, winner.id),
          relatedTerms: clean(winner.relatedTerms, winner.id),
        ),
      );
    }
    out.sort(
      (a, b) => a.acronym.toLowerCase().compareTo(b.acronym.toLowerCase()),
    );
    // Hai nguồn có thể mô tả cùng một viết tắt dưới hai khóa khái niệm khác
    // nhau; trên sơ đồ sẽ thành hai nút trùng tên nên chỉ giữ nút đầu.
    final seenAcronym = <String>{};
    final unique = <Term>[];
    for (final t in out) {
      if (seenAcronym.add(t.acronym.trim().toLowerCase())) unique.add(t);
    }

    // Cắt theo đúng hạn mức của track: sau khi gộp trùng, danh sách có thể dài
    // hơn số nút đọc được trên sơ đồ.
    final track = trackOf(career);
    final result = track == null ? unique : unique.take(track.limit).toList();
    _careerCache[career] = result;
    return result;
  }

  Map<String, List<Term>> _careerGroups(String career) {
    final groups = <String, List<Term>>{};
    for (final t in _careerPool(career)) {
      final key = (t.concept == null || t.concept!.isEmpty)
          ? '__${t.id}'
          : t.concept!;
      (groups[key] ??= <Term>[]).add(t);
    }
    return groups;
  }

  /// Tập thuật ngữ của một lộ trình: chọn theo từ khóa/chủ đề của track rồi cắt
  /// còn [CareerTrack.limit] nút để sơ đồ tư duy còn đọc được.
  Iterable<Term> _careerPool(String career) {
    final track = trackOf(career);
    if (track == null) {
      return _terms.where((t) => t.career == career);
    }
    // Mục được gắn tay đúng nghề luôn đứng đầu, kể cả khi không khớp từ khóa.
    final curated = <Term>[];
    final scored = <Term>[];
    for (final t in _terms) {
      if (t.career == career) {
        curated.add(t);
      } else if (track.score(t) >= 3) {
        scored.add(t);
      }
    }
    if (curated.isEmpty && scored.isEmpty) {
      // Dữ liệu quá cũ/không khớp từ khóa: quay về cách gắn tay trước đây.
      return _terms.where((t) => t.career == career);
    }
    scored.sort((a, b) => compareCareerTerms(a, b, track));
    // Lấy dư vì bước sau còn gộp các bản trùng khái niệm.
    return [...curated, ...scored.take(track.limit * 3)];
  }

  /// Chọn bản đại diện khi một khái niệm có nhiều nguồn: ưu tiên bản đã dịch,
  /// rồi bản có ẩn dụ/giải thích đầy đủ hơn, cuối cùng là id để ổn định.
  static bool _preferTerm(Term a, Term b) {
    int score(Term t) {
      var s = t.needsTranslation ? 0 : 100;
      if ((t.metaphorAnalogy ?? '').trim().isNotEmpty) s += 10;
      if ((t.detailedExplanation ?? '').trim().isNotEmpty) s += 5;
      final confidence = t.attribution.isEmpty
          ? 0
          : (t.attribution.first.confidence ?? 0);
      return s + confidence;
    }

    final diff = score(a) - score(b);
    return diff != 0 ? diff > 0 : a.id.compareTo(b.id) > 0;
  }

  /// Tiến độ lộ trình tính ngay từ cache in-memory (không cần chờ SQLite), để
  /// dashboard và header sơ đồ cập nhật tức thì sau khi đánh dấu đã học.
  int careerProgressSync(String career) {
    final groups = _careerGroups(career);
    if (groups.isEmpty) return 0;
    final done = groups.values.where((group) {
      return group.any((t) => _study[t.id]?.learned ?? false);
    }).length;
    return (done * 100 / groups.length).round();
  }

  /// Số thuật ngữ đã hoàn thành / tổng số nút của lộ trình (đã gộp trùng).
  (int done, int total) careerCounts(String career) {
    final groups = _careerGroups(career);
    final done = groups.values.where((group) {
      return group.any((t) => _study[t.id]?.learned ?? false);
    }).length;
    return (done, groups.length);
  }

  StudyState cachedStudyState(String termId) =>
      _study[termId] ?? StudyState.empty;

  Map<String, StudyState> get allStudyStates => _study;

  /// Kho đang có sẵn trên máy — cho người dùng biết mình đang tra cứu bao nhiêu mục từ.
  int get termCount => _terms.length;

  /// Số biến thể/acronym đã ánh xạ (K8s, CI-CD, ...) — hiển thị ở Cài đặt.
  int get aliasCount => _aliases.length;

  /// Số khái niệm được từ hai nguồn độc lập trở lên cùng định nghĩa (điểm tin cậy cao nhất).
  int get corroboratedConceptCount =>
      _byConcept.values.where((l) => l.length > 1).length;

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
  ///
  /// Đánh dấu "đã học" phải đưa thẻ vào hàng chờ ôn ngay (due = bây giờ); nếu
  /// để due null thì màn Ôn tập luôn báo "không có thẻ đến hạn" dù người dùng
  /// vừa đánh dấu — lỗi luồng SRS 1 → 3 → 7 ngày.
  Future<int> toggleLearned(String termId) async {
    final current = _study[termId] ?? StudyState.empty;
    final nowLearned = !current.learned;
    final now = DateTime.now().toUtc();
    final dueDate = nowLearned
        ? (current.dueDate ?? now.toIso8601String())
        : null;
    final needsReview = !nowLearned;

    await GlossaryDatabase.instance.saveStudyState(
      termId: termId,
      learned: nowLearned,
      needsReview: needsReview,
      intervalDays: current.intervalDays,
      dueDate: dueDate,
      streak: current.streak,
    );
    _study[termId] = StudyState(
      termId: termId,
      learned: nowLearned,
      needsReview: needsReview,
      intervalDays: current.intervalDays,
      dueDate: dueDate,
      streak: current.streak,
      lastActivity: now.toIso8601String(),
    );
    _bumpProgress();
    return careerProgressSync(_byId[termId]?.career ?? '');
  }

  /// FR-QUIZ-01: ghi nhận một thuật ngữ vừa được mở để nó có thể vào đề trắc
  /// nghiệm kể cả khi người dùng chưa bấm "đã học". Chỉ ghi lần đầu, không
  /// làm mất lịch ôn hiện có.
  Future<void> recordView(String termId) async {
    if (!_loaded) await warmUp();
    if (_study.containsKey(termId) || !_byId.containsKey(termId)) return;
    await GlossaryDatabase.instance.saveStudyState(
      termId: termId,
      learned: false,
      intervalDays: 0,
      dueDate: null,
      streak: 0,
    );
    _study[termId] = StudyState(
      termId: termId,
      learned: false,
      intervalDays: 0,
      dueDate: null,
      streak: 0,
      lastActivity: DateTime.now().toUtc().toIso8601String(),
    );
    _bumpProgress();
  }

  /// Các thuật ngữ tương tác gần nhất, mới nhất trước — cho mục "Tiếp tục học".
  List<Term> recentTerms({int limit = 6}) {
    final rows =
        _study.values
            .where((s) => s.lastActivity != null && _byId.containsKey(s.termId))
            .toList()
          ..sort((a, b) => b.lastActivity!.compareTo(a.lastActivity!));
    return rows.take(limit).map((s) => _byId[s.termId]!).toList();
  }

  /// Xóa tiến độ học/ôn nhưng giữ nguyên kho thuật ngữ đóng gói.
  Future<void> resetProgress() async {
    await GlossaryDatabase.instance.clearStudyStates();
    // Không dùng `const {}`: map const là unmodifiable, lần đánh dấu kế tiếp sẽ
    // ném "Cannot modify unmodifiable map".
    _study = <String, StudyState>{};
    _bumpProgress();
  }

  /// FR-QUIZ-02: ôn flashcard -> tính chu kỳ lặp lại tiếp theo (1/3/7 ngày) + streak.
  ///
  /// "Chưa nhớ" chuyển trạng thái sang Cần ôn tập (không còn tính hoàn thành
  /// lộ trình) và hẹn lại sau 1 ngày, thay vì vẫn giữ nhãn Đã học.
  Future<StudyState> reviewFlashcard(
    String termId, {
    required bool remembered,
  }) async {
    final current = _study[termId] ?? StudyState.empty;
    final interval = remembered ? nextIntervalDays(current.intervalDays) : 1;
    final streak = remembered ? current.streak + 1 : 0;
    final now = DateTime.now().toUtc();
    final due = now.add(Duration(days: interval)).toIso8601String();

    await GlossaryDatabase.instance.saveStudyState(
      termId: termId,
      learned: remembered,
      needsReview: !remembered,
      intervalDays: interval,
      dueDate: due,
      streak: streak,
    );

    final next = StudyState(
      termId: termId,
      learned: remembered,
      needsReview: !remembered,
      intervalDays: interval,
      dueDate: due,
      streak: streak,
      lastActivity: now.toIso8601String(),
    );
    _study[termId] = next;
    _bumpProgress();
    return next;
  }

  /// Hàng chờ ôn tập: thẻ quá hạn hôm nay, ưu tiên streak cao hơn.
  List<Term> dueFlashcards() {
    final now = DateTime.now().toUtc();
    final due =
        _study.values
            .where(
              (s) =>
                  s.dueDate != null && !DateTime.parse(s.dueDate!).isAfter(now),
            )
            .toList()
          ..sort((a, b) => b.streak.compareTo(a.streak));
    return due.map((s) => _byId[s.termId]).whereType<Term>().toList();
  }


  /// Phạm vi thẻ cho một phiên ôn.
  ///
  /// Trước đây màn Ôn tập chỉ lấy thẻ đã quá hạn nên người mới mở app thấy
  /// "chưa có thẻ nào" và không có cách nào làm lại từ đã học.
  List<Term> flashcardDeck(
    FlashcardScope scope, {
    String? career,
    int limit = 30,
  }) {
    List<Term> inCareer(Iterable<Term> terms) {
      if (career == null || career.isEmpty) return terms.toList();
      final ids = termsByCareer(career).map((t) => t.id).toSet();
      return terms.where((t) => ids.contains(t.id)).toList();
    }

    final due = inCareer(dueFlashcards());
    switch (scope) {
      case FlashcardScope.due:
        return due.take(limit).toList();
      case FlashcardScope.fresh:
        return inCareer(_freshPool())
            .take(limit)
            .toList();
      case FlashcardScope.learned:
        return inCareer(
          _byId.values.where((t) => _study[t.id]?.learned ?? false),
        ).take(limit).toList();
      case FlashcardScope.all:
        final seen = due.map((t) => t.id).toSet();
        final fresh = inCareer(_freshPool())
            .where((t) => !seen.contains(t.id))
            .take(limit);
        return [...due.take(limit), ...fresh].take(limit).toList();
    }
  }

  /// Thuật ngữ chưa từng chạm tới, xếp theo bảng chữ cái để phiên học ổn định.
  Iterable<Term> _freshPool() {
    final fresh = _byId.values
        .where((t) => !_study.containsKey(t.id))
        .toList()
      ..sort(
        (a, b) => a.acronym.toLowerCase().compareTo(b.acronym.toLowerCase()),
      );
    return fresh;
  }

  /// Số thẻ sẵn có theo từng phạm vi — hiển thị trên chip chọn phạm vi.
  Map<FlashcardScope, int> flashcardCounts({String? career}) => {
    for (final scope in FlashcardScope.values)
      scope: flashcardDeck(scope, career: career, limit: 100000).length,
  };

  /// FR-QUIZ-01: sinh 5–10 câu trắc nghiệm từ thuật ngữ đã xem hoặc đã học.
  ///
  /// Câu hỏi đảo chiều luân phiên (viết tắt → định nghĩa và định nghĩa → viết
  /// tắt) để người học không đoán vị trí đáp án. Trả rỗng nếu chưa đủ 5 thuật
  /// ngữ theo điều kiện tiên quyết của SRS.
  List<QuizQuestion> buildQuiz({int? size}) {
    // Gộp bản trùng acronym (cùng một thuật ngữ từ nhiều nguồn) để phương án
    // nhiễu không lặp y hệt đáp án đúng.
    final byAcronym = <String, Term>{};
    for (final id in _study.keys) {
      final term = _byId[id];
      if (term == null) continue;
      final key = term.acronym.trim().toLowerCase();
      final current = byAcronym[key];
      if (current == null ||
          (current.needsTranslation && !term.needsTranslation)) {
        byAcronym[key] = term;
      }
    }

    final pool = byAcronym.values.toList();
    if (pool.length < 5) return const [];

    final count = (size ?? pool.length).clamp(5, 10);
    pool.shuffle();
    final chosen = pool.take(count).toList();
    final questions = <QuizQuestion>[];

    for (var i = 0; i < chosen.length; i++) {
      final correct = chosen[i];
      final kind = i.isEven
          ? QuizKind.acronymToDefinition
          : QuizKind.definitionToAcronym;

      final others = pool.where((t) => t.id != correct.id).toList()..shuffle();
      final options = <String>[];
      if (kind == QuizKind.acronymToDefinition) {
        options.add(correct.shortDefinition);
        for (final t in others) {
          final candidate = t.shortDefinition.trim();
          if (candidate.isNotEmpty &&
              !options.contains(candidate) &&
              options.length < 4) {
            options.add(candidate);
          }
        }
      } else {
        options.add(correct.acronym);
        for (final t in others) {
          final candidate = t.acronym.trim();
          if (candidate.isNotEmpty &&
              !options.contains(candidate) &&
              options.length < 4) {
            options.add(candidate);
          }
        }
      }
      options.shuffle();

      final prompt = kind == QuizKind.acronymToDefinition
          ? 'Nghĩa của "${correct.acronym}" là gì?'
          : 'Thuật ngữ nào khớp với định nghĩa sau?\n“${_shorten(correct.shortDefinition)}”';

      questions.add(
        QuizQuestion(
          term: correct,
          kind: kind,
          prompt: prompt,
          options: options,
          correctIndex: options.indexOf(
            kind == QuizKind.acronymToDefinition
                ? correct.shortDefinition
                : correct.acronym,
          ),
        ),
      );
    }
    return questions;
  }

  static String _shorten(String text, {int max = 150}) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.length <= max
        ? clean
        : '${clean.substring(0, max).trimRight()}…';
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

enum QuizKind { acronymToDefinition, definitionToAcronym }

class QuizQuestion {
  const QuizQuestion({
    required this.term,
    required this.kind,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final Term term;
  final QuizKind kind;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  String get correctAnswer => options[correctIndex];

  /// Giải thích ngắn hiển thị sau khi chọn, giúp người học nhớ vì sao đúng/sai.
  String get explanation => '${term.acronym} — ${term.shortDefinition}';
}

/// Kết quả một lần Delta Sync.
class SyncOutcome {
  const SyncOutcome({
    required this.ok,
    this.updated = 0,
    this.deleted = 0,
    this.serverTimestamp = 0,
    this.partial = false,
  });

  const SyncOutcome.failed()
    : ok = false,
      updated = 0,
      deleted = 0,
      serverTimestamp = 0,
      partial = false;

  final bool ok;
  final int updated;
  final int deleted;
  final int serverTimestamp;

  /// Mất mạng giữa chừng: đã ghi được một phần lô, con trỏ chưa dịch nên lần
  /// sau kéo tiếp. Khác với [ok] == false (không lấy được gì).
  final bool partial;
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
