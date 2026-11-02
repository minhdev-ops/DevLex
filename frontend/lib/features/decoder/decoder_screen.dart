import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/context_decoder.dart';
import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';
import '../detail/term_detail_screen.dart';

class DecoderScreen extends StatefulWidget {
  const DecoderScreen({super.key});

  @override
  State<DecoderScreen> createState() => _DecoderScreenState();
}

class _DecoderScreenState extends State<DecoderScreen> {
  final _controller = TextEditingController();
  final _repo = GlossaryRepository.instance;
  static const _sample =
      'Cần tuyển vị trí Backend Dev hiểu biết về REST API, JWT và triển khai trên K8s.';

  List<InlineSpan>? _spans;
  bool _truncated = false;
  final List<TapGestureRecognizer> _recognizers = [];

  static const _decoder = ContextDecoder();

  @override
  void initState() {
    super.initState();
    _controller.text = _sample;
    _repo.warmUp().then((_) => _analyze());
  }

  Brightness? _brightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Đổi sáng/tối phải tô lại chữ đã highlight, vì màu được chốt vào span
    // lúc phân tích văn bản.
    final next = Theme.of(context).brightness;
    if (_brightness != null && _brightness != next && _spans != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _analyze();
      });
    }
    _brightness = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// FR-DEC-01: tách từ, khớp CSDL thuật ngữ, highlight acronym tìm được.
  /// Văn bản vượt 10.000 ký tự được cắt bớt (không crash) và báo cho người dùng.
  void _analyze() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final result = _decoder.decode(
      _controller.text,
      (t) => _repo.findByAcronymExact(t)?.id,
    );
    final spans = <InlineSpan>[];
    final matches = <Term>[];
    final theme = Theme.of(context);

    for (final token in result.tokens) {
      final term = token.termId == null ? null : _repo.termById(token.termId!);
      if (term == null) {
        spans.add(
          TextSpan(
            text: token.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        );
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _showPopover(term);
        _recognizers.add(recognizer);
        if (!matches.any((m) => m.id == term.id)) matches.add(term);
        spans.add(
          TextSpan(
            text: token.text,
            // onPrimaryContainer trên nền primaryContainer là cặp màu M3
            // đảm bảo tương phản ở cả nền sáng và tối; trước đây dùng
            // primary trên nền primaryContainer mờ nên chữ gần như biến mất
            // khi bật giao diện tối.
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
            recognizer: recognizer,
          ),
        );
      }
    }

    setState(() {
      _spans = spans;
      _found = matches;
      _truncated = result.truncated;
    });
  }

  List<Term> _found = const [];

  /// FR-DEC-02: popover Tầng 1 tại chỗ chạm, không chuyển trang.
  void _showPopover(Term term) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.acronym,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              term.bilingualName,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tầng 1: ${term.shortDefinition}',
              style: Theme.of(sheetContext).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Mã thuật ngữ: ${term.id}',
              style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // FR-DEC-03: mở bài viết 3 tầng hoàn chỉnh.
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Xem chi tiết'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TermDetailScreen(termId: term.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clipboard đang trống.')));
      return;
    }
    _controller.text = text;
    _analyze();
  }

  void _clearText() {
    _controller.clear();
    _analyze();
  }

  void _useSample() {
    _controller.text = _sample;
    _analyze();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = _controller.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giải mã ngữ cảnh'),
        actions: [
          IconButton(
            tooltip: 'Dán từ clipboard',
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
          if (!empty)
            IconButton(
              tooltip: 'Xóa văn bản',
              onPressed: _clearText,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Phân tích lại',
            onPressed: _analyze,
            icon: const Icon(Icons.auto_fix_high),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Dán đoạn văn bản kỹ thuật / tin tuyển dụng (JD) để hệ thống quét và giải mã từ viết tắt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            inputFormatters: [
              LengthLimitingTextInputFormatter(_decoder.maxChars),
            ],
            decoration: const InputDecoration(
              hintText: 'Dán nội dung tại đây (dưới 10.000 ký tự)...',
            ),
            onChanged: (_) => _analyze(),
          ),
          const SizedBox(height: 16),
          if (_truncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Văn bản vượt 10.000 ký tự — hệ thống chỉ phân tích 10.000 ký tự đầu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (empty)
            _DecoderEmpty(onSample: _useSample, onPaste: _pasteFromClipboard)
          else if (_spans != null) ...[
            Row(
              children: [
                Icon(Icons.tag, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _found.isEmpty
                        ? 'Chưa tìm thấy thuật ngữ nào trong đoạn văn này'
                        : 'Tìm thấy ${_found.length} thuật ngữ — chạm từ được highlight để xem nhanh',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (_found.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _found
                    .map(
                      (t) => ActionChip(
                        avatar: const Icon(Icons.search, size: 14),
                        label: Text(t.acronym),
                        onPressed: () => _showPopover(t),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text.rich(TextSpan(children: _spans!)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecoderEmpty extends StatelessWidget {
  const _DecoderEmpty({required this.onSample, required this.onPaste});

  final VoidCallback onSample;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.article_outlined, size: 52, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'Dán một đoạn JD hoặc tài liệu kỹ thuật',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Hệ thống sẽ tự tìm các từ viết tắt và thuật ngữ đã biết, '
            'chạm vào từ được tô màu để xem định nghĩa Tầng 1 ngay tại chỗ.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste_go_outlined),
                label: const Text('Dán từ clipboard'),
              ),
              OutlinedButton.icon(
                onPressed: onSample,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Dùng ví dụ mẫu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
