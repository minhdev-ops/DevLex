/// FR-MAP-01/02: quan hệ tiên quyết giữa các thuật ngữ của một lộ trình.
/// Tách khỏi widget để kiểm thử được mà không cần SQLite hay asset.
class KnowledgeGraph {
  KnowledgeGraph(Iterable<Iterable<String>> edges)
      : _prerequisites = _group(edges, take: 1, give: 0),
        _dependents = _group(edges, take: 0, give: 1);

  final Map<String, Set<String>> _prerequisites;
  final Map<String, Set<String>> _dependents;
  final Map<String, int> _layerMemo = {};
  final Set<String> _visiting = {};

  static Map<String, Set<String>> _group(
    Iterable<Iterable<String>> edges, {
    required int take,
    required int give,
  }) {
    final out = <String, Set<String>>{};
    for (final e in edges) {
      (out[e.elementAt(take)] ??= <String>{}).add(e.elementAt(give));
    }
    return out;
  }

  /// Tầng = độ dài chuỗi tiên quyết dài nhất dẫn tới node, nên một node luôn
  /// đứng sau mọi tiên quyết của nó. Chu trình trong dữ liệu nguồn bị cắt tại
  /// chỗ quay lại chính nó thay vì đệ quy vô hạn.
  int layerOf(String id) {
    final known = _layerMemo[id];
    if (known != null) return known;
    if (!_visiting.add(id)) return 0;
    var layer = 0;
    for (final p in _prerequisites[id] ?? const <String>{}) {
      final candidate = 1 + layerOf(p);
      if (candidate > layer) layer = candidate;
    }
    _visiting.remove(id);
    return _layerMemo[id] = layer;
  }

  /// Gom node theo tầng để xếp cột; tầng 0 là hàng đợi tiên quyết ngoài cùng trái.
  Map<int, List<String>> layers(Iterable<String> ids) {
    final buckets = <int, List<String>>{};
    for (final id in ids) {
      (buckets[layerOf(id)] ??= <String>[]).add(id);
    }
    final keys = buckets.keys.toList()..sort();
    return {for (final k in keys) k: buckets[k]!};
  }

  Set<String> prerequisitesOf(String id) => {..._prerequisites[id] ?? const <String>{}};

  Set<String> dependentsOf(String id) => {..._dependents[id] ?? const <String>{}};

  Set<String> prereqClosure(String id) => _closure(id, _prerequisites);

  Set<String> dependentClosure(String id) => _closure(id, _dependents);

  /// "Nhánh liên quan" của một node: chính nó + toàn bộ tổ tiên và hậu duệ.
  Set<String> branchOf(String id) => {id, ...prereqClosure(id), ...dependentClosure(id)};

  static Set<String> _closure(String id, Map<String, Set<String>> adjacency) {
    final out = <String>{};
    final queue = [...(adjacency[id] ?? const <String>{})];
    while (queue.isNotEmpty) {
      final next = queue.removeLast();
      if (!out.add(next)) continue;
      queue.addAll(adjacency[next] ?? const <String>{});
    }
    return out;
  }
}
