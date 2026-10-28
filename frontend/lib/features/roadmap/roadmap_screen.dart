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
  bool _graphView = true;

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
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Sơ đồ'), icon: Icon(Icons.account_tree_outlined)),
              ButtonSegment(value: false, label: Text('Danh sách'), icon: Icon(Icons.list)),
            ],
            selected: {_graphView},
            onSelectionChanged: (s) => setState(() => _graphView = s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
        ],
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
              : _graphView
                  ? KnowledgeGraphView(terms: _terms, repo: _repo, onChanged: _refresh)
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

/// FR-MAP-01: sơ đồ nút tương tác theo tầng prerequisite (bố cục phân lớp, cạnh nối,
/// pan/zoom). FR-MAP-02: chạm nút -> card nhanh Tầng 1 + highlight prerequisite.
class KnowledgeGraphView extends StatelessWidget {
  const KnowledgeGraphView({super.key, required this.terms, required this.repo, required this.onChanged});

  final List<Term> terms;
  final GlossaryRepository repo;
  final VoidCallback onChanged;

  static const _nodeW = 120.0;
  static const _nodeH = 56.0;
  static const _xGap = 180.0;
  static const _yGap = 96.0;
  static const _pad = 24.0;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final t in terms) t.id: t};
    final cols = <int, List<Term>>{};
    final depthMemo = <String, int>{};

    int depthOf(Term t, Set<String> stack) {
      if (depthMemo.containsKey(t.id)) return depthMemo[t.id]!;
      if (stack.contains(t.id)) return 0; // chặn vòng
      stack.add(t.id);
      var d = 0;
      for (final p in t.prerequisites) {
        final pt = byId[p];
        if (pt != null) {
          d = (d > 1 + depthOf(pt, stack)) ? d : 1 + depthOf(pt, stack);
        }
      }
      stack.remove(t.id);
      return depthMemo[t.id] = d;
    }

    // xếp theo cột = tầng prerequisite
    for (final t in terms) {
      (cols[depthOf(t, {})] ??= []).add(t);
    }
    final colKeys = cols.keys.toList()..sort();
    final pos = <String, Offset>{};
    for (final c in colKeys) {
      final list = cols[c]!;
      for (var r = 0; r < list.length; r++) {
        pos[list[r].id] = Offset(_pad + c * _xGap, _pad + r * _yGap);
      }
    }

    final maxCol = colKeys.isEmpty ? 0 : colKeys.last;
    var maxRow = 0;
    for (final c in colKeys) {
      if (cols[c]!.length > maxRow) maxRow = cols[c]!.length;
    }
    final canvas = Size(_pad * 2 + (maxCol + 1) * _xGap, _pad * 2 + maxRow * _yGap);

    // cạnh = cặp (prereq -> term) nằm trong tập hiện có
    final edges = <List<String>>[];
    for (final t in terms) {
      for (final p in t.prerequisites) {
        if (byId.containsKey(p)) edges.add([p, t.id]);
      }
    }

    return InteractiveViewer(
      minScale: 0.4,
      maxScale: 2.5,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: canvas.width,
          height: canvas.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EdgePainter(pos: pos, edges: edges, nodeW: _nodeW, nodeH: _nodeH),
                ),
              ),
              for (final t in terms)
                Positioned(
                  left: pos[t.id]!.dx,
                  top: pos[t.id]!.dy,
                  child: _GraphNode(
                    term: t,
                    learned: repo.cachedStudyState(t.id).learned,
                    width: _nodeW,
                    height: _nodeH,
                    onTap: () => _openQuickCard(context, t),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuickCard(BuildContext context, Term term) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => _QuickCardSheet(
        term: term,
        repo: repo,
        onOpenDetail: () {
          Navigator.of(sheetCtx).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TermDetailScreen(termId: term.id)),
          );
        },
        onToggleLearned: () async {
          await repo.toggleLearned(term.id);
          onChanged();
        },
      ),
    );
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.term,
    required this.learned,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Term term;
  final bool learned;
  final double width, height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: learned ? AppTheme.tier2.withValues(alpha: 0.16) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: learned ? AppTheme.tier2 : scheme.outlineVariant,
            width: learned ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: scheme.shadow.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(term.acronym,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (learned) const Icon(Icons.check_circle, size: 12, color: AppTheme.tier2),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.pos, required this.edges, required this.nodeW, required this.nodeH});

  final Map<String, Offset> pos;
  final List<List<String>> edges;
  final double nodeW, nodeH;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final e in edges) {
      final from = pos[e[0]], to = pos[e[1]];
      if (from == null || to == null) continue;
      final start = Offset(from.dx + nodeW, from.dy + nodeH / 2);
      final end = Offset(to.dx, to.dy + nodeH / 2);
      final mid = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
      // mũi tên nhỏ ở đầu đến
      canvas.drawCircle(end, 2.5, Paint()..color = const Color(0xFF9AA0A6));
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.pos != pos || old.edges != edges;
}

class _QuickCardSheet extends StatelessWidget {
  const _QuickCardSheet({
    required this.term,
    required this.repo,
    required this.onOpenDetail,
    required this.onToggleLearned,
  });

  final Term term;
  final GlossaryRepository repo;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggleLearned;

  @override
  Widget build(BuildContext context) {
    final learned = repo.cachedStudyState(term.id).learned;
    final prereqs = term.prerequisites.map(repo.termById).whereType<Term>().toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(term.acronym, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: Icon(learned ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: learned ? AppTheme.tier2 : null),
                tooltip: learned ? 'Bỏ đánh dấu đã học' : 'Đánh dấu đã học',
                onPressed: onToggleLearned,
              ),
            ],
          ),
          Text(term.fullNameEn, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(term.shortDefinition),
          if (prereqs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Cần biết trước', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: prereqs
                  .map((p) => Chip(
                        label: Text(p.acronym),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppTheme.tier1.withValues(alpha: 0.10),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onOpenDetail,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Xem chi tiết 3 tầng'),
            ),
          ),
        ],
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
