/// Chuẩn hóa payload Delta Sync (API nested snake_case) thành dạng rows phẳng
/// camelCase mà SQLite cục bộ + Term.fromJson dùng. Thuần -> unit-test không cần DB/mạng.
class SyncResult {
  const SyncResult({
    required this.rows,
    required this.deletedIds,
    required this.serverTimestamp,
    this.hasMore = false,
    this.nextCursor,
  });

  /// Các term đã cập nhật, sẵn sàng upsert vào SQLite.
  final List<Map<String, dynamic>> rows;

  /// id các term bị xóa phía server (hard-delete ở phase sau; hiện thường rỗng).
  final List<String> deletedIds;

  /// Mốc thời gian server -> lưu làm last_pulled_at cho lần sync kế.
  final int serverTimestamp;

  /// Server còn lô tiếp theo cho cùng một lần sync (keyset pagination).
  final bool hasMore;

  /// Con trỏ mờ (opaque) dùng để lấy trang kế; null khi đã hết.
  final String? nextCursor;
}

class SyncNormalizer {
  const SyncNormalizer._();

  static SyncResult normalize(Map<String, dynamic> delta) {
    final changes = (delta['changes'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final updated = changes['updated'] as List? ?? const [];
    final deleted = changes['deleted_ids'] as List? ?? const [];

    return SyncResult(
      rows: updated.whereType<Map>().map((e) => _toLocalRow(e.cast<String, dynamic>())).toList(growable: false),
      deletedIds: deleted.map((e) => e.toString()).toList(growable: false),
      serverTimestamp: (delta['sync_timestamp'] as num?)?.toInt() ?? 0,
      hasMore: delta['has_more'] == true,
      nextCursor: delta['next_cursor'] as String?,
    );
  }

  static Map<String, dynamic> _toLocalRow(Map<String, dynamic> api) {
    final t1 = (api['tier_1'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final t2 = (api['tier_2'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final t3 = (api['tier_3'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    return <String, dynamic>{
      'id': api['id'] as String? ?? '',
      'acronym': t1['acronym'] as String? ?? '',
      'fullNameEn': t1['full_name_en'] as String? ?? '',
      'fullNameVi': t1['full_name_vi'] as String? ?? '',
      'shortDefinition': t1['short_definition'] as String? ?? '',
      'detailedExplanation': t2['detailed_explanation'],
      'metaphorAnalogy': t2['metaphor_analogy'],
      'diagramUrl': t2['diagram_url'],
      'categoryTags': (t3['category_tags'] as List<dynamic>?) ?? const [],
      'difficulty': t3['difficulty_level'] as String? ?? 'Beginner',
      'prerequisites': (t3['prerequisites'] as List<dynamic>?) ?? const [],
      'relatedTerms': (t3['related_terms'] as List<dynamic>?) ?? const [],
      'career': api['roadmap_career'],
      'concept': api['concept'],
      'attribution': (api['source_attribution'] as List<dynamic>?) ?? const [],
    };
  }
}
