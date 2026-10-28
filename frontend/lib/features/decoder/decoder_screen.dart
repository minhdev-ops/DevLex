import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _controller.text = _sample;
    _repo.warmUp().then((_) => _analyze());
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
  void _analyze() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = _controller.text;
    final spans = <InlineSpan>[];
    final matches = <Term>[];

    // Token hóa giữ nguyên ký tự phân cách giữa các từ.
    final tokens = RegExp(r'[A-Za-z0-9/]+|[^A-Za-z0-9/]+').allMatches(text);
    final theme = Theme.of(context);

    for (final m in tokens) {
      final token = m.group(0)!;
      final term = _repo.findByAcronymExact(token);
      if (term == null) {
        spans.add(TextSpan(text: token, style: theme.textTheme.bodyLarge));
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _showPopover(term);
        _recognizers.add(recognizer);
        matches.add(term);
        spans.add(TextSpan(
          text: token,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          ),
          recognizer: recognizer,
        ));
      }
    }

    setState(() {
      _spans = spans;
      _found = matches;
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
            Text(term.acronym,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('${term.fullNameEn} — ${term.fullNameVi}',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 12),
            Text('Tầng 1: ${term.shortDefinition}',
                style: Theme.of(sheetContext).textTheme.bodyLarge),
            const SizedBox(height: 16),
            // FR-DEC-03: mở bài viết 3 tầng hoàn chỉnh.
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Xem chi tiết'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TermDetailScreen(termId: term.id)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giải mã ngữ cảnh'),
        actions: [
          IconButton(onPressed: _analyze, icon: const Icon(Icons.auto_fix_high)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dán đoạn văn bản kỹ thuật / tin tuyển dụng (JD) để hệ thống quét và giải mã từ viết tắt.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Dán nội dung tại đây (dưới 10.000 ký tự)...',
            ),
            onChanged: (_) => _analyze(),
          ),
          const SizedBox(height: 16),
          if (_spans != null) ...[
            Row(
              children: [
                Icon(Icons.tag, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Tìm thấy ${_found.length} thuật ngữ — chạm từ được highlight để xem nhanh',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
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
