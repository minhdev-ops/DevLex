import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/knowledge_graph.dart';
import '../../core/roadmap_selection.dart';
import '../../data/career_tracks.dart';
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
    _career = RoadmapSelection.instance.value;
    RoadmapSelection.instance.addListener(_onExternalSelection);
    _repo.warmUp().then((_) => _refresh());
  }

  @override
  void dispose() {
    RoadmapSelection.instance.removeListener(_onExternalSelection);
    super.dispose();
  }

  void _onExternalSelection() {
    final next = RoadmapSelection.instance.value;
    if (next == _career) return;
    setState(() => _career = next);
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _terms = _repo.termsByCareer(_career);
      _progress = _repo.careerProgressSync(_career);
      _ready = true;
    });
  }

  Future<void> _pickCareer() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CareerPicker(current: _career),
    );
    if (picked != null && mounted) _selectCareer(picked);
  }

  void _selectCareer(String career) {
    if (_career == career) return;
    setState(() => _career = career);
    if (RoadmapSelection.instance.value != career) {
      RoadmapSelection.instance.value = career;
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final graph = KnowledgeGraph([
      for (final t in _terms)
        for (final p in t.prerequisites)
          if (_terms.any((x) => x.id == p)) [p, t.id],
    ]);
    final ordered = _orderedByLayer(_terms, graph);
    Term? next;
    for (final t in ordered) {
      if (!_repo.cachedStudyState(t.id).learned) {
        next = t;
        break;
      }
    }

    // Màn hẹp (360dp): bỏ icon trong segmented button để AppBar không tràn.
    final compact = MediaQuery.sizeOf(context).width < 400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sơ đồ lộ trình'),
        actions: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: const Text('Sơ đồ'),
                icon: compact ? null : const Icon(Icons.account_tree_outlined),
              ),
              ButtonSegment(
                value: false,
                label: const Text('Danh sách'),
                icon: compact ? null : const Icon(Icons.list),
              ),
            ],
            selected: {_graphView},
            onSelectionChanged: (s) => setState(() => _graphView = s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              // 13 lộ trình không nhét vừa một hàng chip: dùng nút mở bộ chọn
              // nhóm theo mảng để thanh trên không bị rối.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickCareer,
                    icon: const Icon(Icons.route_outlined, size: 18),
                    label: Row(
                      children: [
                        Expanded(
                          child: Text(
                            GlossaryRepository.careers[_career] ??
                                'Chọn lộ trình',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _progress / 100,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_progress%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
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
          : Column(
              children: [
                _CareerSummary(
                  label: GlossaryRepository.careers[_career]!,
                  progress: _progress,
                  counts: _repo.careerCounts(_career),
                  next: next,
                  onOpenNext: next == null
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TermDetailScreen(termId: next!.id),
                            ),
                          );
                          _refresh();
                        },
                ),
                Expanded(
                  child: _graphView
                      ? KnowledgeGraphView(
                          terms: _terms,
                          repo: _repo,
                          onChanged: _refresh,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: ordered.length,
                          itemBuilder: (context, i) => _MapNodeTile(
                            term: ordered[i],
                            step: i + 1,
                            repo: _repo,
                            onChanged: _refresh,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Thứ tự học gợi ý: theo tầng tiên quyết, trong cùng tầng xếp theo tên.
List<Term> _orderedByLayer(List<Term> terms, KnowledgeGraph graph) {
  final byId = {for (final t in terms) t.id: t};
  final layers = graph.layers(byId.keys);
  final out = <Term>[];
  final keys = layers.keys.toList()..sort();
  for (final layer in keys) {
    final ids = [...layers[layer]!]
      ..sort(
        (a, b) => byId[a]!.acronym.toLowerCase().compareTo(
          byId[b]!.acronym.toLowerCase(),
        ),
      );
    out.addAll(ids.map((id) => byId[id]!));
  }
  return out;
}

/// Bộ chọn lộ trình: nhóm theo mảng nghề để 13 lộ trình vẫn gọn một màn.
class _CareerPicker extends StatelessWidget {
  const _CareerPicker({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = careerGroups;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Chọn lộ trình nghề nghiệp',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  entry.key.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final track in entry.value)
                ListTile(
                  leading: Icon(
                    track.key == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: track.key == current
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(track.label),
                  selected: track.key == current,
                  onTap: () => Navigator.of(context).pop(track.key),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tóm tắt lộ trình: tiến độ + gợi ý thuật ngữ kế tiếp, để người dùng không
/// phải tự dò trên sơ đồ lớn.
class _CareerSummary extends StatelessWidget {
  const _CareerSummary({
    required this.label,
    required this.progress,
    required this.counts,
    required this.next,
    this.onOpenNext,
  });

  final String label;
  final int progress;
  final (int done, int total) counts;
  final Term? next;
  final VoidCallback? onOpenNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${counts.$1}/${counts.$2} · $progress%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: onOpenNext,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 18,
                        color: AppTheme.tier2,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Học tiếp: ${next!.acronym}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 18,
                    color: AppTheme.tier3,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bạn đã hoàn thành toàn bộ lộ trình này.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// FR-MAP-01/02: sơ đồ nút theo tầng tiên quyết (bố cục phân lớp, cạnh nối,
/// pan/zoom). Chạm nút -> card Tầng 1, highlight nhánh liên quan và nhảy dọc
/// cạnh tiên quyết mà không phải rời sơ đồ.
class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    super.key,
    required this.terms,
    required this.repo,
    required this.onChanged,
  });

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
  static const _minScale = 0.35;
  static const _maxScale = 2.5;

  /// Controller tường minh để ngoài thao tác chụm hai ngón còn có nút phóng
  /// to / thu nhỏ / canh vừa màn hình — người dùng không quen gesture vẫn xem
  /// được toàn bộ sơ đồ.
  final _view = TransformationController();

  /// Kích thước thật của khung sơ đồ (không phải cả màn hình) để canh giữa đúng.
  Size _viewSize = Size.zero;

  String? _selectedId;
  bool _showHint = true;
  Size _canvas = Size.zero;
  bool _needFit = true;

  @override
  void didUpdateWidget(covariant KnowledgeGraphView old) {
    super.didUpdateWidget(old);
    // Đổi lộ trình thì node đang chọn có thể không còn thuộc tập mới.
    if (_selectedId != null && widget.terms.every((t) => t.id != _selectedId)) {
      _selectedId = null;
    }
    // Đổi lộ trình thì canh lại khung nhìn; chấm điểm thẻ chỉ đổi trạng thái
    // node nên phải giữ nguyên chỗ người dùng đang xem.
    final sameShape =
        old.terms.length == widget.terms.length &&
        (old.terms.isEmpty || old.terms.first.id == widget.terms.first.id);
    if (!sameShape) _needFit = true;
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _select(String? id) => setState(() => _selectedId = id);

  double get _scale => _view.value.getMaxScaleOnAxis();

  /// Thu phóng quanh tâm khung nhìn để nội dung không nhảy ra ngoài màn hình.
  void _zoomTo(double target) {
    final box = _viewSize;
    if (box.isEmpty) return;
    final current = _scale;
    final next = target.clamp(_minScale, _maxScale);
    if ((next - current).abs() < 0.001) return;
    final k = next / current;
    final t = _view.value.getTranslation();
    final cx = box.width / 2;
    final cy = box.height / 2;
    _view.value = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, cx - (cx - t.x) * k)
      ..setEntry(1, 3, cy - (cy - t.y) * k);
  }

  /// Canh toàn bộ sơ đồ vào khung nhìn, không phóng quá cỡ thật.
  void _fitToView() {
    final box = _viewSize;
    if (box.isEmpty || _canvas.isEmpty) return;
    final byWidth = box.width / _canvas.width;
    final byHeight = box.height / _canvas.height;
    final scale = (byWidth < byHeight ? byWidth : byHeight).clamp(
      _minScale,
      1.0,
    );
    _view.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, (box.width - _canvas.width * scale) / 2)
      ..setEntry(1, 3, (box.height - _canvas.height * scale) / 2);
  }

  @override
  Widget build(BuildContext context) {
    final terms = widget.terms;
    final byId = {for (final t in terms) t.id: t};

    // cạnh chỉ có nghĩa khi cả hai đầu nằm trong lộ trình đang xem
    // Cạnh có hướng: tiên quyết -> phụ thuộc (vẽ mũi tên).
    final edges = <List<String>>[
      for (final t in terms)
        for (final p in t.prerequisites)
          if (byId.containsKey(p)) [p, t.id],
    ];
    // Liên quan: phần lớn kho dữ liệu không có cạnh tiên quyết, chỉ có liên
    // quan, nên nếu bỏ qua thì sơ đồ trơ ra các ô rời rạc không có hướng.
    final related = <List<String>>[
      for (final t in terms)
        for (final r in t.relatedTerms)
          if (byId.containsKey(r) && r != t.id && t.id.compareTo(r) < 0)
            [t.id, r],
    ];
    final graph = KnowledgeGraph(edges);

    final pos = <String, Offset>{};
    final columnFirst = <String>[];
    final columnLast = <String>[];
    var maxRow = 0;
    var maxCol = 0;
    // Xếp mỗi tầng thành cột, nhưng cắt cột sau 10 nút: kho thuật ngữ phần lớn
    // không có cạnh tiên quyết nên nếu dồn một cột dọc thì sơ đồ thành dải dài
    // và bị thu nhỏ đến mức không đọc được.
    const rowsPerColumn = 10;
    var column = 0;
    final layers = graph.layers(byId.keys);
    final layerKeys = layers.keys.toList()..sort();
    for (final layer in layerKeys) {
      final ids = [...layers[layer]!]
        ..sort(
          (a, b) => byId[a]!.acronym.toLowerCase().compareTo(
            byId[b]!.acronym.toLowerCase(),
          ),
        );
      for (var start = 0; start < ids.length; start += rowsPerColumn) {
        final chunk = ids.sublist(
          start,
          (start + rowsPerColumn).clamp(0, ids.length),
        );
        if (chunk.length > maxRow) maxRow = chunk.length;
        for (var r = 0; r < chunk.length; r++) {
          pos[chunk[r]] = Offset(_pad + column * _xGap, _pad + r * _yGap);
        }
        columnFirst.add(chunk.first);
        columnLast.add(chunk.last);
        column++;
      }
    }
    maxCol = column == 0 ? 0 : column - 1;

    // Không có cạnh tiên quyết nào trong tập này (phổ biến với kho hiện tại):
    // nối các cột bằng mũi tên để người đọc vẫn thấy chiều học trái -> phải.
    if (edges.isEmpty) {
      for (var i = 0; i + 1 < columnFirst.length; i++) {
        edges.add([columnFirst[i], columnFirst[i + 1]]);
      }
    }

    final canvas = Size(
      _pad * 2 + (maxCol + 1) * _xGap,
      _pad * 2 + (maxRow == 0 ? 1 : maxRow) * _yGap,
    );
    _canvas = canvas;
    if (_needFit) {
      _needFit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToView();
      });
    }

    final selected = (_selectedId != null && byId.containsKey(_selectedId))
        ? _selectedId!
        : null;
    final ancestors = selected == null
        ? const <String>{}
        : graph.prereqClosure(selected);
    final descendants = selected == null
        ? const <String>{}
        : graph.dependentClosure(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewSize = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _view,
                constrained: false,
                minScale: _minScale,
                maxScale: _maxScale,
                // Cho phép kéo quá mép: sơ đồ nhỏ hơn khung nhìn vẫn di chuyển
                // được thay vì đứng yên như bị khoá.
                boundaryMargin: const EdgeInsets.all(4000),
                onInteractionStart: (_) {
                  if (_showHint) setState(() => _showHint = false);
                },
                child: SizedBox(
                  width: canvas.width,
                  height: canvas.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _EdgePainter(
                            pos: pos,
                            edges: edges,
                            related: related,
                            nodeW: _nodeW,
                            nodeH: _nodeH,
                            branch: selected == null
                                ? null
                                : graph.branchOf(selected),
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
                            needsReview: widget.repo
                                .cachedStudyState(t.id)
                                .needsReview,
                            role: _roleOf(
                              t.id,
                              selected,
                              ancestors,
                              descendants,
                            ),
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
            if (_showHint)
              const Positioned(
                left: 12,
                bottom: 70,
                child: IgnorePointer(child: _MapHint()),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Phóng to',
                    onPressed: () => _zoomTo(_scale * 1.35),
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  IconButton.filledTonal(
                    tooltip: 'Thu nhỏ',
                    onPressed: () => _zoomTo(_scale / 1.35),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 8),
                  IconButton.filledTonal(
                    tooltip: 'Vừa màn hình',
                    onPressed: _fitToView,
                    icon: const Icon(Icons.fit_screen_outlined),
                  ),
                ],
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
      },
    );
  }

  static _NodeRole _roleOf(
    String id,
    String? selected,
    Set<String> ancestors,
    Set<String> descendants,
  ) {
    if (selected == null) return _NodeRole.plain;
    if (id == selected) return _NodeRole.selected;
    if (ancestors.contains(id)) return _NodeRole.ancestor;
    if (descendants.contains(id)) return _NodeRole.descendant;
    return _NodeRole.unrelated;
  }

  /// FR-MAP-02: card nhanh Tầng 1; chạm chip tiên quyết / kế tiếp thì đổi trọng
  /// tâm ngay trên sơ đồ, chỉ rời sơ đồ khi người dùng bấm "Xem chi tiết 3 tầng".
  Future<void> _openQuickCard(
    Map<String, Term> byId,
    KnowledgeGraph graph,
    Term term,
  ) async {
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
          onNavigate: (next) =>
              Navigator.of(sheetCtx).pop(_SheetMove.to(next.id)),
          onOpenDetail: () =>
              Navigator.of(sheetCtx).pop(const _SheetMove.detail()),
          onToggleLearned: () async {
            await widget.repo.toggleLearned(current.id);
            widget.onChanged();
          },
        ),
      );
      if (move == null || !mounted) return;
      if (move.toDetail) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TermDetailScreen(termId: current.id),
          ),
        );
        widget.onChanged();
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

/// Gợi ý thao tác trên sơ đồ; tự ẩn sau lần chạm/kéo đầu tiên để không rối mắt.
class _MapHint extends StatelessWidget {
  const _MapHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pan_tool_alt_outlined,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Kéo để di chuyển · Chụm 2 ngón để thu phóng · mũi tên chỉ chiều học',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
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
    required this.needsReview,
    required this.role,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Term term;
  final bool learned;
  final bool needsReview;
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
            color:
                accent?.withValues(alpha: 0.14) ??
                (learned
                    ? AppTheme.tier2.withValues(alpha: 0.16)
                    : (needsReview
                          ? AppTheme.warning.withValues(alpha: 0.12)
                          : scheme.surface)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  accent ??
                  (learned
                      ? AppTheme.tier2
                      : (needsReview
                            ? AppTheme.warning
                            : scheme.outlineVariant)),
              width: accent != null ? 2.4 : ((learned || needsReview) ? 2 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                term.acronym,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (learned)
                const Icon(Icons.check_circle, size: 12, color: AppTheme.tier2)
              else if (needsReview)
                const Icon(Icons.refresh, size: 12, color: AppTheme.warning),
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
    this.related = const [],
    required this.nodeW,
    required this.nodeH,
    this.branch,
  });

  final Map<String, Offset> pos;

  /// Cạnh có hướng: [từ, đến] theo tiên quyết.
  final List<List<String>> edges;

  /// Cạnh liên quan (không hướng), vẽ nét đứt mảnh hơn.
  final List<List<String>> related;

  final double nodeW, nodeH;

  /// Hai đầu cùng nằm trong nhánh đang xem thì cạnh được tô đậm.
  final Set<String>? branch;

  static const _idle = Color(0xFF9AA0A6);
  static const _arrow = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in related) {
      final from = pos[e[0]], to = pos[e[1]];
      if (from == null || to == null) continue;
      _drawLink(
        canvas,
        from,
        to,
        Paint()
          ..color = _idle.withValues(alpha: 0.45)
          ..strokeWidth = 1,
        dashed: true,
      );
    }

    for (final e in edges) {
      final from = pos[e[0]], to = pos[e[1]];
      if (from == null || to == null) continue;
      final onBranch =
          branch != null && branch!.contains(e[0]) && branch!.contains(e[1]);
      final paint = Paint()
        ..color = onBranch ? AppTheme.primary : _idle
        ..strokeWidth = onBranch ? 2.4 : 1.6
        ..style = PaintingStyle.stroke;
      final end = _drawLink(canvas, from, to, paint);
      _drawArrowHead(canvas, end, paint.color);
    }
  }

  /// Vẽ đường nối từ mép phải nút nguồn tới mép trái nút đích, trả về điểm cuối.
  Offset _drawLink(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    bool dashed = false,
  }) {
    final start = Offset(from.dx + nodeW, from.dy + nodeH / 2);
    final end = Offset(to.dx, to.dy + nodeH / 2);
    final mid = (start.dx + end.dx) / 2;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);

    if (!dashed) {
      canvas.drawPath(path, paint);
      return end;
    }
    // Nét đứt: cắt đường cong thành từng đoạn ngắn.
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + 5;
      }
    }
    return end;
  }

  /// Mũi tên chỉ chiều học: từ tiên quyết sang thuật ngữ phụ thuộc.
  void _drawArrowHead(Canvas canvas, Offset tip, Color color) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - _arrow, tip.dy - _arrow * 0.55)
      ..lineTo(tip.dx - _arrow, tip.dy + _arrow * 0.55)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.pos != pos ||
      old.edges != edges ||
      old.related != related ||
      old.branch != branch;
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
                Text(
                  term.acronym,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  icon: Icon(
                    _learned
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _learned ? AppTheme.tier2 : null,
                  ),
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
              _BranchChips(
                terms: prerequisites,
                tone: AppTheme.tier1,
                onTap: onNavigate,
              ),
            ],
            if (unlocks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BranchLabel('Mở khóa cho', Icons.arrow_forward, AppTheme.tier3),
              const SizedBox(height: 6),
              _BranchChips(
                terms: unlocks,
                tone: AppTheme.tier3,
                onTap: onNavigate,
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
  const _BranchChips({
    required this.terms,
    required this.tone,
    required this.onTap,
  });

  final List<Term> terms;
  final Color tone;
  final ValueChanged<Term> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    children: terms
        .map(
          (p) => ActionChip(
            label: Text(p.acronym),
            visualDensity: VisualDensity.compact,
            avatar: Icon(Icons.call_made, size: 12, color: tone),
            backgroundColor: tone.withValues(alpha: 0.10),
            onPressed: () => onTap(p),
          ),
        )
        .toList(),
  );
}

/// FR-MAP-02: nút thuật ngữ trên cây -> xem nhanh Tầng 1 + highlight prerequisites.
class _MapNodeTile extends StatelessWidget {
  const _MapNodeTile({
    required this.term,
    required this.step,
    required this.repo,
    required this.onChanged,
  });

  final Term term;
  final int step;
  final GlossaryRepository repo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final state = repo.cachedStudyState(term.id);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TermDetailScreen(termId: term.id),
            ),
          );
          onChanged();
        },
        leading: SizedBox(
          width: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: state.learned
                    ? AppTheme.tier2.withValues(alpha: 0.14)
                    : scheme.surfaceContainerHighest,
                child: state.learned
                    ? const Icon(Icons.check, size: 16, color: AppTheme.tier2)
                    : (state.needsReview
                          ? const Icon(
                              Icons.refresh,
                              size: 16,
                              color: AppTheme.warning,
                            )
                          : Text(
                              step.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            )),
              ),
            ],
          ),
        ),
        title: Text(
          term.acronym,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.shortDefinition,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (term.prerequisites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: term.prerequisites
                      .map((p) => repo.termById(p))
                      .whereType<Term>()
                      .map(
                        (p) => Chip(
                          label: Text('cần: ${p.acronym}'),
                          visualDensity: VisualDensity.compact,
                          labelStyle: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
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
