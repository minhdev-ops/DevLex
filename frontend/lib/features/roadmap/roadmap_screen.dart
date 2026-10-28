import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';
import '../detail/term_detail_screen.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _repo = GlossaryRepository.instance;
  String _career = 'frontend';
  int _progress = 0;
  List<Term> _terms = const [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _repo.warmUp().then((_) => _refresh());
  }

  Future<void> _refresh() async {
    final pct = await _repo.careerProgress(_career);
    if (!mounted) return;
    setState(() {
      _terms = _repo.termsByCareer(_career);
      _progress = pct;
      _ready = true;
    });
  }

  void _selectCareer(String career) {
    setState(() => _career = career);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sơ đồ lộ trình'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: GlossaryRepository.careers.entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(e.value),
                              selected: _career == e.key,
                              onSelected: (_) => _selectCareer(e.key),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(value: _progress / 100, minHeight: 8),
                    ),
                    const SizedBox(width: 12),
                    Text('$_progress%', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _terms.isEmpty
              ? const Center(child: Text('Chưa có thuật ngữ cho lộ trình này.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _terms.length,
                  itemBuilder: (context, i) => _MapNodeTile(
                    term: _terms[i],
                    repo: _repo,
                    onChanged: _refresh,
                  ),
                ),
    );
  }
}

/// FR-MAP-02: nút thuật ngữ trên cây -> xem nhanh Tầng 1 + highlight prerequisites.
class _MapNodeTile extends StatelessWidget {
  const _MapNodeTile({required this.term, required this.repo, required this.onChanged});

  final Term term;
  final GlossaryRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final state = repo.cachedStudyState(term.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TermDetailScreen(termId: term.id)),
        ),
        leading: Icon(
          state.learned ? Icons.check_circle : Icons.radio_button_unchecked,
          color: state.learned ? AppTheme.tier2 : Theme.of(context).colorScheme.outline,
        ),
        title: Text(term.acronym, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(term.shortDefinition,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            if (term.prerequisites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: term.prerequisites
                      .map((p) => repo.termById(p))
                      .whereType<Term>()
                      .map((p) => Chip(
                            label: Text('cần: ${p.acronym}'),
                            visualDensity: VisualDensity.compact,
                            labelStyle: Theme.of(context).textTheme.labelSmall,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.school_outlined),
          tooltip: state.learned ? 'Bỏ đánh dấu đã học' : 'Đánh dấu đã học',
          onPressed: () async {
            await repo.toggleLearned(term.id);
            onChanged();
          },
        ),
      ),
    );
  }
}
