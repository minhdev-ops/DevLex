import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/knowledge_graph.dart';
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

/// FR-MAP-01/02: sơ đồ nút theo tầng tiên quyết (bố cục phân lớp, cạnh nối,
/// pan/zoom). Chạm nút -> card Tầng 1, highlight nhánh liên quan và nhảy dọc
/// cạnh tiên quyết mà không phải rời sơ đồ.
class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({super.key, required this.terms, required this.repo, required this.onChanged});

  final List<Term> terms;
  final GlossaryRepository repo;
  final VoidCallback onChanged;

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
  static const _nodeW = 120.0;
  static const _nodeH = 56.0;
  static const _xGap = 180.0;
  static const _yGap = 96.0;
  static const _pad = 24.0;

  String? _selectedId;

  @override
  void didUpdateWidget(covariant KnowledgeGraphView old) {
    super.didUpdateWidget(old);
    // Đổi lộ trình thì node đang chọn có thể không còn thuộc tập mới.
    if (_selectedId != null && widget.terms.every((t) => t.id != _selectedId)) {
      _selectedId = null;
    }
  }

  void _select(String? id) => setState(() => _selectedId = id);

  @override
  Widget build(BuildContext context) {
    final terms = widget.terms;
    final byId = {for (final t in terms) t.id: t};

    // cạnh chỉ có nghĩa khi cả hai đầu nằm trong lộ trình đang xem
    final edges = <List<String>>[
      for (final t in terms)
        for (final p in t.prerequisites)
          if (byId.containsKey(p)) [p, t.id],
    ];
    final graph = KnowledgeGraph(edges);

    final pos = <String, Offset>{};
    var maxRow = 0;
    var maxCol = 0;
    graph.layers(byId.keys).forEach((layer, ids) {
      if (layer > maxCol) maxCol = layer;
      if (ids.length > maxRow) maxRow = ids.length;
      for (var r = 0; r < ids.length; r++) {
        pos[ids[r]] = Offset(_pad + layer * _xGap, _pad + r * _yGap);
      }
    });

    final selected = (_selectedId != null && byId.containsKey(_selectedId)) ? _selectedId! : null;
    final ancestors = selected == null ? const <String>{} : graph.prereqClosure(selected);
    final descendants = selected == null ? const <String>{} : graph.dependentClosure(selected);

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.4,
            maxScale: 2.5,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _pad * 2 + (maxCol + 1) * _xGap,
                height: _pad * 2 + (maxRow == 0 ? 1 : maxRow) * _yGap,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EdgePainter(
                          pos: pos,
                          edges: edges,
                          nodeW: _nodeW,
                          nodeH: _nodeH,
                          branch: selected == null ? null : graph.branchOf(selected),
                        ),
                      ),
                    ),
                    for (final t in terms)
                      Positioned(
                        left: pos[t.id]!.dx,
                        top: pos[t.id]!.dy,
                        child: _GraphNode(
                          term: t,
                          learned: widget.repo.cachedStudyState(t.id).learned,
                          role: _roleOf(t.id, selected, ancestors, descendants),
                          width: _nodeW,
                          height: _nodeH,
                          onTap: () {
                            _select(t.id);
                            _openQuickCard(byId, graph, t);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: FilledButton.tonalIcon(
              onPressed: () => _select(null),
              icon: const Icon(Icons.clear),
              label: Text('Bỏ nhánh của ${byId[selected]!.acronym}'),
            ),
          ),
      ],
    );
  }

  static _NodeRole _roleOf(String id, String? selected, Set<String> ancestors, Set<String> descendants) {
    if (selected == null) return _NodeRole.plain;
    if (id == selected) return _NodeRole.selected;
    if (ancestors.contains(id)) return _NodeRole.ancestor;
    if (descendants.contains(id)) return _NodeRole.descendant;
    return _NodeRole.unrelated;
  }

  /// FR-MAP-02: card nhanh Tầng 1; chạm chip tiên quyết / kế tiếp thì đổi trọng
  /// tâm ngay trên sơ đồ, chỉ rời sơ đồ khi người dùng bấm "Xem chi tiết 3 tầng".
  Future<void> _openQuickCard(Map<String, Term> byId, KnowledgeGraph graph, Term term) async {
    var current = term;
    while (mounted) {
      final move = await showModalBottomSheet<_SheetMove>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetCtx) => _QuickCardSheet(
          term: current,
          repo: widget.repo,
          prerequisites: _neighbors(graph.prerequisitesOf(current.id), byId),
          unlocks: _neighbors(graph.dependentsOf(current.id), byId),
          onNavigate: (next) => Navigator.of(sheetCtx).pop(_SheetMove.to(next.id)),
          onOpenDetail: () => Navigator.of(sheetCtx).pop(const _SheetMove.detail()),
          onToggleLearned: () async {
            await widget.repo.toggleLearned(current.id);
            widget.onChanged();
          },
        ),
      );
      if (move == null || !mounted) return;
      if (move.toDetail) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TermDetailScreen(termId: current.id)),
        );
        return;
      }
      final next = byId[move.termId];
      if (next == null) return;
      current = next;
      _select(next.id);
    }
  }

  static List<Term> _neighbors(Set<String> ids, Map<String, Term> byId) => [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
}

/// Trọng tâm highlight của sơ đồ khi một node được chọn.
enum _NodeRole { plain, selected, ancestor, descendant, unrelated }

/// Kết quả card nhanh: nhảy tới node khác, mở trang chi tiết, hoặc đóng.
class _SheetMove {
  const _SheetMove.to(this.termId) : toDetail = false;
  const _SheetMove.detail() : termId = null, toDetail = true;

  final String? termId;
  final bool toDetail;
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.term,
    required this.learned,
    required this.role,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Term term;
  final bool learned;
  final _NodeRole role;
  final double width, height;
  final VoidCallback onTap;

  static const _accent = {
    _NodeRole.selected: AppTheme.primary,
    _NodeRole.ancestor: AppTheme.tier1,
    _NodeRole.descendant: AppTheme.tier3,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent[role];
    final dim = role == _NodeRole.unrelated;
    return Opacity(
      opacity: dim ? 0.32 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: accent?.withValues(alpha: 0.14) ??
                (learned ? AppTheme.tier2.withValues(alpha: 0.16) : scheme.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent ?? (learned ? AppTheme.tier2 : scheme.outlineVariant),
              width: accent != null ? 2.4 : (learned ? 2 : 1),
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
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.pos,
    required this.edges,
    required this.nodeW,
    required this.nodeH,
    this.branch,
  });

  final Map<String, Offset> pos;
  final List<List<String>> edges;
  final double nodeW, nodeH;

  /// Hai đầu cùng nằm trong nhánh đang xem thì cạnh được tô đậm.
  final Set<String>? branch;

  static const _idle = Color(0xFF9AA0A6);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final from = pos[e[0]], to = pos[e[1]];
      if (from == null || to == null) continue;
      final onBranch = branch != null && branch!.contains(e[0]) && branch!.contains(e[1]);
      final paint = Paint()
        ..color = onBranch ? AppTheme.primary : _idle
        ..strokeWidth = onBranch ? 2.4 : 1.5
        ..style = PaintingStyle.stroke;
      final start = Offset(from.dx + nodeW, from.dy + nodeH / 2);
      final end = Offset(to.dx, to.dy + nodeH / 2);
      final mid = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
      // mũi tên nhỏ ở đầu đến
      canvas.drawCircle(end, 2.5, Paint()..color = paint.color);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.pos != pos || old.edges != edges || old.branch != branch;
}

class _QuickCardSheet extends StatelessWidget {
  const _QuickCardSheet({
    required this.term,
    required this.repo,
    required this.prerequisites,
    required this.unlocks,
    required this.onNavigate,
    required this.onOpenDetail,
    required this.onToggleLearned,
  });

  final Term term;
  final GlossaryRepository repo;
  final List<Term> prerequisites;
  final List<Term> unlocks;
  final ValueChanged<Term> onNavigate;
  final VoidCallback onOpenDetail;
  final Future<void> Function() onToggleLearned;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(term.acronym, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    term.bilingualName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: Icon(_learned ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _learned ? AppTheme.tier2 : null),
                  tooltip: _learned ? 'Bỏ đánh dấu đã học' : 'Đánh dấu đã học',
                  onPressed: () async {
                    await onToggleLearned();
                    setSheetState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(term.shortDefinition),
            if (prerequisites.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BranchLabel('Cần biết trước', Icons.arrow_back, AppTheme.tier1),
              const SizedBox(height: 6),
              _BranchChips(terms: prerequisites, tone: AppTheme.tier1, onTap: onNavigate),
            ],
            if (unlocks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BranchLabel('Mở khóa cho', Icons.arrow_forward, AppTheme.tier3),
              const SizedBox(height: 6),
              _BranchChips(terms: unlocks, tone: AppTheme.tier3, onTap: onNavigate),
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
      ),
    );
  }

  bool get _learned => repo.cachedStudyState(term.id).learned;
}

class _BranchLabel extends StatelessWidget {
  const _BranchLabel(this.text, this.icon, this.tone);

  final String text;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelLarge),
        ],
      );
}

class _BranchChips extends StatelessWidget {
  const _BranchChips({required this.terms, required this.tone, required this.onTap});

  final List<Term> terms;
  final Color tone;
  final ValueChanged<Term> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        children: terms
            .map((p) => ActionChip(
                  label: Text(p.acronym),
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.call_made, size: 12, color: tone),
                  backgroundColor: tone.withValues(alpha: 0.10),
                  onPressed: () => onTap(p),
                ))
            .toList(),
      );
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
