import 'package:flutter/material.dart';

import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';
import '../detail/term_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _repo = GlossaryRepository.instance;
  List<SearchResult> _results = const [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _repo.warmUp().then((_) => setState(() => _ready = true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final sw = Stopwatch()..start();
    final results = _repo.search(value);
    sw.stop();
    setState(() {
      _results = results;
    });
    if (value.isNotEmpty) {
      debugPrint('search "$value": ${results.length} results in ${sw.elapsedMilliseconds}ms');
    }
  }

  void _openTerm(SearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermDetailScreen(termId: result.term.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IT Glossary',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Tra cứu thuật ngữ IT — 3 tầng tri thức, hoạt động offline',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    onChanged: _ready ? _onQueryChanged : null,
                    decoration: InputDecoration(
                      hintText: 'Thử tìm: API, K8s, JWT, Docker...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _results.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                              },
                            ),
                    ),
                  ),
                  if (_ready && _results.isEmpty && _controller.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Không tìm thấy kết quả phù hợp.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _ready
                  ? _results.isEmpty
                      ? _BrowsePlaceholder(
                          onPick: (t) {
                            _controller.text = t;
                            _onQueryChanged(t);
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _TermResultTile(
                                  result: _results[index],
                                  onTap: () => _openTerm(_results[index]),
                              ),
                        )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermResultTile extends StatelessWidget {
  const _TermResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final term = result.term;
    final alias = result.matchedAlias;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(
                term.acronym,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (result.similarity > 0 && result.similarity < 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${(result.similarity * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${term.fullNameEn} — ${term.fullNameVi}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(term.shortDefinition,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            if (alias?.namingRuleNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(alias!.namingRuleNote!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.tertiary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrowsePlaceholder extends StatelessWidget {
  const _BrowsePlaceholder({required this.onPick});

  final ValueChanged<String> onPick;

  static const _popular = ['API', 'K8s', 'JWT', 'Docker', 'REST', 'CI/CD'];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore,
                size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('Khám phá thuật ngữ IT',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Nhập từ khóa để bắt đầu. Thử với các thuật ngữ phổ biến:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _popular
                  .map((t) => ActionChip(label: Text(t), onPressed: () => onPick(t)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
