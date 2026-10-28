import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
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
