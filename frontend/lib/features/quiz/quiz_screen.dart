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

  @override
  void initState() {
    super.initState();
    _repo.warmUp().then((_) => _load());
  }

  void _load() {
    setState(() {
      _queue = _repo.dueFlashcards();
      _cardIndex = 0;
      _showBack = false;
      _ready = true;
    });
  }

  Future<void> _grade(bool remembered) async {
    final term = _queue[_cardIndex];
    await _repo.reviewFlashcard(term.id, remembered: remembered);
    setState(() {
      _showBack = false;
      _cardIndex++;
    });
  }

  void _startQuiz() {
    setState(() {
      _quiz = _repo.buildQuiz();
      _quizIndex = 0;
      _selected = null;
      _score = 0;
      _mode = _Mode.quiz;
    });
  }

  _Mode _mode = _Mode.review;

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
            tooltip: _mode == _Mode.quiz ? 'Quay lại Flashcard' : 'Làm trắc nghiệm',
            icon: Icon(_mode == _Mode.quiz ? Icons.replay : Icons.quiz_outlined),
            onPressed: () => setState(
                () => _mode = _mode == _Mode.quiz ? _Mode.review : _Mode.quiz),
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

    if (_queue.isEmpty || _cardIndex >= _queue.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_outlined, size: 48),
            const SizedBox(height: 12),
            Text(streak > 0 ? 'Streak tốt nhất: $streak ngày liên tiếp' : 'Chưa có thẻ đến hạn ôn.',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Đánh dấu "đã học" ở tab Lộ trình hoặc Tra cứu để thêm thẻ vào hàng chờ.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            if (_queue.isNotEmpty && _cardIndex >= _queue.length) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Kiểm tra lại')),
            ],
          ],
        ),
      );
    }

    final term = _queue[_cardIndex];
    final state = _repo.cachedStudyState(term.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('${_cardIndex + 1} / ${_queue.length}   •   streak cá nhân: ${state.streak}',
              style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => setState(() => _showBack = !_showBack),
              child: Card(
                margin: EdgeInsets.zero,
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _showBack
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(term.shortDefinition,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium),
                              if (term.metaphorAnalogy != null) ...[
                                const SizedBox(height: 12),
                                Text(term.metaphorAnalogy!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.tier2,
                                        )),
                              ],
                            ],
                          )
                        : Text(term.acronym,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _showBack
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Chưa nhớ'),
                        onPressed: () => _grade(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.tier2),
                        icon: const Icon(Icons.check),
                        label: const Text('Đã nhớ'),
                        onPressed: () => _grade(true),
                      ),
                    ),
                  ],
                )
              : OutlinedButton(onPressed: () => setState(() => _showBack = true), child: const Text('Lật thẻ')),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
              Text('Cần tối thiểu 5 thuật ngữ đã học/xem để sinh bài trắc nghiệm.\nHãy đánh dấu "đã học" vài thuật ngữ trước.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => setState(() => _mode = _Mode.review),
                  child: const Text('Về Flashcard')),
            ],
          ),
        ),
      );
    }

    if (_quizIndex >= _quiz.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 48, color: AppTheme.tier3),
            const SizedBox(height: 12),
            Text('Hoàn thành: $_score / ${_quiz.length}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: _startQuiz, child: const Text('Làm lại')),
          ],
        ),
      );
    }

    final q = _quiz[_quizIndex];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Câu ${_quizIndex + 1}/${_quiz.length}',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Text('Nghĩa của "${q.term.acronym}" là?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...List.generate(q.options.length, (i) {
          final isCorrect = i == q.correctIndex;
          final isSelected = _selected == i;
          final answered = _selected != null;

          Color? bg;
          if (answered && isCorrect) bg = AppTheme.tier2.withValues(alpha: 0.15);
          if (answered && isSelected && !isCorrect) bg = Colors.red.withValues(alpha: 0.12);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: answered
                  ? null
                  : () async {
                      final remembered = i == q.correctIndex;
                      if (remembered) _score++;
                      await _repo.reviewFlashcard(q.term.id, remembered: remembered);
                      setState(() {
                        _selected = i;
                      });
                      await Future<void>.delayed(const Duration(milliseconds: 900));
                      setState(() {
                        _quizIndex++;
                        _selected = null;
                      });
                    },
              child: Text(q.options[i]),
            ),
          );
        }),
      ],
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
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiến trình ghi nhớ', style: theme.textTheme.titleMedium),
              if (stats.tracked == 0) ...[
                const SizedBox(height: 20),
                const Center(
                    child: Icon(Icons.psychology_outlined, size: 44, color: Color(0xFF9AA6B2))),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                      'Chưa có thẻ nào được theo dõi.\nĐánh dấu "đã học" ở Lộ trình hoặc Tra cứu để '
                      'bắt đầu chu kỳ ôn 1 → 3 → 7 ngày.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
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
              Text('${stats.points}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(width: 8),
              Text('điểm động lực', style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${stats.day1} thẻ ×2 · ${stats.day3} thẻ ×5 · ${stats.day7} thẻ ×10 · '
            'streak ${stats.bestStreak} ×3',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        Text('Phân bố ${stats.tracked} thẻ',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (var i = 0; i < rungs.length; i++)
                  if (rungs[i].$2 > 0)
                    Expanded(flex: rungs[i].$2, child: ColoredBox(color: _rungColors[i])),
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
                    decoration:
                        BoxDecoration(color: _rungColors[i], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(child: Text(rungs[i].$1, style: theme.textTheme.bodyMedium)),
                Text('${rungs[i].$2}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              Text('Không còn thẻ đến hạn hôm nay.', style: theme.textTheme.bodyMedium),
            ],
          ),
      ],
    );
  }
}
