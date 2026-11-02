import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/study_stats.dart';
import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _repo = GlossaryRepository.instance;
  bool _ready = false;

  List<Term> _queue = const [];
  int _cardIndex = 0;
  bool _showBack = false;

  List<QuizQuestion> _quiz = const [];
  int _quizIndex = 0;
  int? _selected;
  int _score = 0;
  final List<QuizQuestion> _wrong = [];

  int _sessionRemembered = 0;
  int _sessionForgot = 0;

  /// Đang ghi kết quả chấm: bỏ qua tín hiệu tiến độ do chính mình phát ra.
  bool _grading = false;

  @override
  void initState() {
    super.initState();
    _repo.warmUp().then((_) => _load());
    _repo.progressRevision.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    _repo.progressRevision.removeListener(_onProgressChanged);
    super.dispose();
  }

  /// Học ở tab khác xong thì hàng chờ phải cập nhật — nhưng không được cắt
  /// ngang phiên đang làm dở, nên chỉ nạp lại khi chưa bắt đầu hoặc đã hết thẻ.
  void _onProgressChanged() {
    if (!mounted || _grading || _mode != _Mode.review) return;
    if (_cardIndex != 0 && _cardIndex < _queue.length) return;
    _load();
  }

  /// Phạm vi thẻ đang học: mặc định trộn thẻ đến hạn với từ mới.
  FlashcardScope _scope = FlashcardScope.all;

  /// Id các thẻ đã chấm trong phiên — dùng cho nút "Làm lại phiên này".
  final List<String> _sessionIds = [];

  void _load() {
    setState(() {
      _queue = _repo.flashcardDeck(_scope);
      _cardIndex = 0;
      _showBack = false;
      _sessionRemembered = 0;
      _sessionForgot = 0;
      _sessionIds.clear();
      _ready = true;
    });
  }

  void _setScope(FlashcardScope scope) {
    if (_scope == scope) return;
    _scope = scope;
    _load();
  }

  /// Làm lại đúng những thẻ vừa chấm, không phụ thuộc lịch SRS.
  void _restartSession() {
    final ids = _sessionIds.toList();
    if (ids.isEmpty) {
      _load();
      return;
    }
    setState(() {
      _queue = ids.map(_repo.termById).whereType<Term>().toList();
      _cardIndex = 0;
      _showBack = false;
      _sessionRemembered = 0;
      _sessionForgot = 0;
      _sessionIds.clear();
    });
  }

  Future<void> _grade(bool remembered) async {
    if (_queue.isEmpty || _cardIndex >= _queue.length) return;
    final term = _queue[_cardIndex];
    _grading = true;
    await _repo.reviewFlashcard(term.id, remembered: remembered);
    _grading = false;
    if (!mounted) return;
    setState(() {
      if (remembered) {
        _sessionRemembered++;
      } else {
        _sessionForgot++;
      }
      _showBack = false;
      _cardIndex++;
      _sessionIds.add(term.id);
    });
  }

  void _startQuiz() {
    setState(() {
      _quiz = _repo.buildQuiz();
      _quizIndex = 0;
      _selected = null;
      _score = 0;
      _wrong.clear();
      _mode = _Mode.quiz;
    });
  }

  Future<void> _answer(int index) async {
    if (_selected != null) return;
    final q = _quiz[_quizIndex];
    final remembered = index == q.correctIndex;
    if (!remembered) _wrong.add(q);
    await _repo.reviewFlashcard(q.term.id, remembered: remembered);
    if (!mounted) return;
    setState(() {
      _selected = index;
      if (remembered) _score++;
    });
  }

  void _nextQuestion() {
    setState(() {
      _quizIndex++;
      _selected = null;
    });
  }

  _Mode _mode = _Mode.review;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == _Mode.quiz ? 'Trắc nghiệm' : 'Ôn tập Flashcard'),
        actions: [
          IconButton(
            tooltip: 'Thống kê ghi nhớ',
            icon: const Icon(Icons.insights_outlined),
            onPressed: _openStats,
          ),
          IconButton(
            tooltip: _mode == _Mode.quiz
                ? 'Quay lại Flashcard'
                : 'Làm trắc nghiệm',
            icon: Icon(
              _mode == _Mode.quiz ? Icons.replay : Icons.quiz_outlined,
            ),
            onPressed: () {
              if (_mode == _Mode.quiz) {
                setState(() => _mode = _Mode.review);
                _load();
              } else {
                _startQuiz();
              }
            },
          ),
        ],
      ),
      body: _mode == _Mode.quiz ? _buildQuiz(context) : _buildReview(context),
    );
  }

  /// FR-QUIZ-03: dashboard tiến trình ghi nhớ + điểm động lực.
  Future<void> _openStats() async {
    final stats = _repo.studyStats();
    final wantReview = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _StatsSheet(stats: stats),
    );
    if (wantReview == true) {
      setState(() => _mode = _Mode.review);
      _load();
    }
  }

  // ---------- FR-QUIZ-02: Flashcard SRS ----------
  Widget _buildReview(BuildContext context) {
    final streak = _repo.totalReviewStreak();
    final finished = _queue.isEmpty || _cardIndex >= _queue.length;

    if (finished) {
      return _ReviewEmpty(
        streak: streak,
        remembered: _sessionRemembered,
        forgot: _sessionForgot,
        hadQueue: _queue.isNotEmpty,
        scope: _scope,
        counts: _repo.flashcardCounts(),
        onScope: _setScope,
        onReload: _load,
        onRestart: _sessionIds.isEmpty ? null : _restartSession,
        onQuiz: () {
          _startQuiz();
        },
      );
    }

    final term = _queue[_cardIndex];
    final state = _repo.cachedStudyState(term.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thẻ ${_cardIndex + 1}/${_queue.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: _queue.isEmpty ? 0 : _cardIndex / _queue.length,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Streak', style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    '${state.streak} ngày',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        _ScopeBar(
          scope: _scope,
          counts: _repo.flashcardCounts(),
          onChanged: _setScope,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          // Wrap thay vì Row: màn 360dp tràn 1px khi hai nhãn cạnh nhau.
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SessionPill(
                icon: Icons.check_circle_outline,
                count: _sessionRemembered,
                label: 'Đã nhớ',
                tone: AppTheme.tier2,
              ),
              _SessionPill(
                icon: Icons.refresh,
                count: _sessionForgot,
                label: 'Chưa nhớ',
                tone: AppTheme.warning,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GestureDetector(
              onTap: () => setState(() => _showBack = !_showBack),
              child: Card(
                margin: EdgeInsets.zero,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _showBack
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                term.acronym,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppTheme.tier2),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                term.shortDefinition,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (term.metaphorAnalogy != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tier2.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    term.metaphorAnalogy!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                'Chạm để lật lại mặt trước',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                term.acronym,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Chạm thẻ để xem định nghĩa',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _showBack
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Chưa nhớ'),
                        onPressed: () => _grade(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.tier2,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Đã nhớ'),
                        onPressed: () => _grade(true),
                      ),
                    ),
                  ],
                )
              : OutlinedButton(
                  onPressed: () => setState(() => _showBack = true),
                  child: const Text('Lật thẻ'),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton.icon(
            icon: const Icon(Icons.quiz_outlined),
            label: const Text('Chuyển sang Trắc nghiệm'),
            onPressed: _startQuiz,
          ),
        ),
      ],
    );
  }

  // ---------- FR-QUIZ-01/03: Trắc nghiệm ----------
  Widget _buildQuiz(BuildContext context) {
    if (_quiz.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Cần tối thiểu 5 thuật ngữ đã xem hoặc đã học để sinh bài trắc nghiệm.\n'
                'Hãy mở vài thuật ngữ ở tab Tra cứu hoặc đánh dấu "đã học" trước.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() => _mode = _Mode.review),
                child: const Text('Về Flashcard'),
              ),
            ],
          ),
        ),
      );
    }

    if (_quizIndex >= _quiz.length) {
      return _buildResult(context);
    }

    final q = _quiz[_quizIndex];
    final answered = _selected != null;
    final correct = answered && _selected == q.correctIndex;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Câu ${_quizIndex + 1}/${_quiz.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Text(
              '$_score đúng',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.tier2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: _quizIndex / _quiz.length,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          q.prompt,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ...List.generate(q.options.length, (i) {
          final isCorrect = i == q.correctIndex;
          final isSelected = _selected == i;

          Color? bg;
          if (answered && isCorrect) {
            bg = AppTheme.tier2.withValues(alpha: 0.15);
          }
          if (answered && isSelected && !isCorrect) {
            bg = Colors.red.withValues(alpha: 0.12);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: bg,
                disabledBackgroundColor: bg,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: answered ? null : () => _answer(i),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(q.options[i])),
                  if (answered && isCorrect)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppTheme.tier2,
                    ),
                  if (answered && isSelected && !isCorrect)
                    Icon(Icons.cancel, size: 18, color: Colors.red.shade700),
                ],
              ),
            ),
          );
        }),
        if (answered) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (correct ? AppTheme.tier2 : Colors.red).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (correct ? AppTheme.tier2 : Colors.red).withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      correct ? Icons.check_circle : Icons.info,
                      size: 18,
                      color: correct ? AppTheme.tier2 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      correct ? 'Chính xác!' : 'Chưa đúng',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  q.explanation,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nextQuestion,
              child: Text(
                _quizIndex == _quiz.length - 1 ? 'Xem kết quả' : 'Câu tiếp',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final total = _quiz.length;
    final percent = total == 0 ? 0 : (_score * 100 / total).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Icon(
          percent >= 80 ? Icons.emoji_events : Icons.flag_outlined,
          size: 56,
          color: percent >= 80 ? AppTheme.tier3 : AppTheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          'Kết quả: $_score/$total',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '$percent% câu trả lời chính xác',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : _score / total,
            minHeight: 10,
          ),
        ),
        if (_wrong.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'Cần ôn lại (${_wrong.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final q in _wrong)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.refresh, color: AppTheme.warning),
                title: Text(
                  q.term.acronym,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  q.term.shortDefinition,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _startQuiz,
          icon: const Icon(Icons.replay),
          label: const Text('Làm lại'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _mode = _Mode.review);
            _load();
          },
          icon: const Icon(Icons.style_outlined),
          label: const Text('Về Flashcard'),
        ),
      ],
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill({
    required this.icon,
    required this.count,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewEmpty extends StatelessWidget {
  const _ReviewEmpty({
    required this.streak,
    required this.remembered,
    required this.forgot,
    required this.hadQueue,
    required this.scope,
    required this.counts,
    required this.onScope,
    required this.onReload,
    required this.onRestart,
    required this.onQuiz,
  });

  final int streak;
  final int remembered;
  final int forgot;
  final bool hadQueue;
  final FlashcardScope scope;
  final Map<FlashcardScope, int> counts;
  final ValueChanged<FlashcardScope> onScope;
  final VoidCallback onReload;
  final VoidCallback? onRestart;
  final VoidCallback onQuiz;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = remembered + forgot;
    final fresh = counts[FlashcardScope.fresh] ?? 0;

    return Column(
      children: [
        _ScopeBar(scope: scope, counts: counts, onChanged: onScope),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  done > 0
                      ? Icons.workspace_premium_outlined
                      : Icons.nightlight_outlined,
                  size: 52,
                  color: done > 0 ? AppTheme.tier3 : scheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  done > 0
                      ? 'Hoàn thành phiên ôn!'
                      : 'Không còn thẻ trong mục này',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  done > 0
                      ? 'Đã nhớ $remembered · Chưa nhớ $forgot\nStreak tốt nhất: $streak ngày liên tiếp'
                      : fresh > 0
                      ? 'Còn $fresh thuật ngữ chưa học — bắt đầu bằng một phiên từ mới.'
                      : 'Bạn đã đi hết kho thuật ngữ. Chọn "Đã học" để làm lại từ đầu.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                if (onRestart != null) ...[
                  FilledButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.replay),
                    label: const Text('Làm lại phiên này'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (fresh > 0)
                  FilledButton.tonalIcon(
                    onPressed: () => onScope(FlashcardScope.fresh),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text('Học tiếp $fresh từ mới'),
                  )
                else if (hadQueue)
                  FilledButton.tonalIcon(
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kiểm tra lại'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onQuiz,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Làm trắc nghiệm'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Chọn phạm vi thẻ: tất cả / cần ôn / từ mới / đã học.
class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.scope,
    required this.counts,
    required this.onChanged,
  });

  final FlashcardScope scope;
  final Map<FlashcardScope, int> counts;
  final ValueChanged<FlashcardScope> onChanged;

  static const _labels = {
    FlashcardScope.all: 'Tất cả',
    FlashcardScope.due: 'Cần ôn',
    FlashcardScope.fresh: 'Từ mới',
    FlashcardScope.learned: 'Đã học',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final s in FlashcardScope.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${_labels[s]} (${counts[s] ?? 0})'),
                selected: scope == s,
                onSelected: (_) => onChanged(s),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

enum _Mode { review, quiz }

/// FR-QUIZ-03: biểu đồ tiến trình ghi nhớ theo 4 bậc SRS + điểm động lực.
class _StatsSheet extends StatelessWidget {
  const _StatsSheet({required this.stats});

  final StudyStats stats;

  static const _rungColors = [
    Color(0xFFB7CBE0), // mới đánh dấu
    AppTheme.primary,
    AppTheme.tier2,
    AppTheme.tier3,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiến trình ghi nhớ', style: theme.textTheme.titleMedium),
              if (stats.tracked == 0) ...[
                const SizedBox(height: 20),
                const Center(
                  child: Icon(
                    Icons.psychology_outlined,
                    size: 44,
                    color: Color(0xFF9AA6B2),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Chưa có thẻ nào được theo dõi.\nĐánh dấu "đã học" ở Lộ trình hoặc Tra cứu để '
                    'bắt đầu chu kỳ ôn 1 → 3 → 7 ngày.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                _pointsCard(theme),
                const SizedBox(height: 20),
                _ladder(theme),
                const SizedBox(height: 20),
                _footer(context, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${stats.points}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('điểm động lực', style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${stats.day1} thẻ ×2 · ${stats.day3} thẻ ×5 · ${stats.day7} thẻ ×10 · '
            'streak ${stats.bestStreak} ×3',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ladder(ThemeData theme) {
    final rungs = stats.ladder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phân bố ${stats.tracked} thẻ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (var i = 0; i < rungs.length; i++)
                  if (rungs[i].$2 > 0)
                    Expanded(
                      flex: rungs[i].$2,
                      child: ColoredBox(color: _rungColors[i]),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rungs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _rungColors[i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(rungs[i].$1, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  '${rungs[i].$2}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _footer(BuildContext context, ThemeData theme) {
    final longTerm = (stats.longTermShare * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats.longTermShare > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '$longTerm% thẻ đã ôn ít nhất một lần đang ở chu kỳ dài nhất (7 ngày).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (stats.dueNow > 0)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.school_outlined),
              label: Text('Ôn ngay (${stats.dueNow} thẻ đến hạn)'),
              onPressed: () => Navigator.pop(context, true),
            ),
          )
        else
          Row(
            children: [
              const Icon(Icons.task_alt, color: AppTheme.tier2),
              const SizedBox(width: 8),
              Text(
                'Không còn thẻ đến hạn hôm nay.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
      ],
    );
  }
}
