import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/knowledge_graph.dart';

/// FR-MAP-01/02: lớp phủ định và nhánh liên quan của sơ đồ lộ trình.
void main() {
  // Chuỗi thẳng + một nhánh tắt: json <- api <- spa, api <- rest
  KnowledgeGraph build() => KnowledgeGraph([
        ['json', 'api'],
        ['api', 'rest'],
        ['api', 'spa'],
      ]);

  group('layerOf', () {
    test('node không có tiên quyết ở tầng 0', () {
      expect(build().layerOf('json'), 0);
    });

    test('xếp sau toàn bộ tiên quyết của nó', () {
      final g = build();
      expect(g.layerOf('api'), 1);
      expect(g.layerOf('spa'), 2);
      expect(g.layerOf('rest'), 2);
    });

    test('đi theo chuỗi dài nhất chứ không theo cạnh ngắn nhất', () {
      // rest trực tiếp phụ thuộc json, nhưng đường qua api dài hơn nên phải ở tầng 2
      final g = KnowledgeGraph([
        ['json', 'api'],
        ['api', 'rest'],
        ['json', 'rest'],
      ]);
      expect(g.layerOf('rest'), 2);
    });

    test('chu trình không làm đệ quy treo', () {
      final g = KnowledgeGraph([
        ['a', 'b'],
        ['b', 'a'],
      ]);
      expect(g.layerOf('a'), lessThan(6));
      expect(g.layerOf('b'), lessThan(6));
    });
  });

  test('layers gom node theo tầng và giữ nguyên số node', () {
    final g = build();
    final layers = g.layers(['json', 'api', 'spa', 'rest', 'khong_ket_noi']);
    expect(layers.keys.toList(), [0, 1, 2]);
    expect(layers[0], containsAll(<String>['json', 'khong_ket_noi']));
    expect(layers[2], containsAll(<String>['spa', 'rest']));
    expect(layers.values.expand((e) => e).length, 5);
  });

  group('nhánh liên quan', () {
    test('kéo theo cả tổ tiên lẫn hậu duệ', () {
      final g = build();
      expect(g.branchOf('api'), {'api', 'json', 'rest', 'spa'});
    });

    test('chỉ có hậu duệ khi đứng ở lá', () {
      final g = build();
      expect(g.prereqClosure('spa'), {'api', 'json'});
      expect(g.dependentClosure('spa'), isEmpty);
    });

    test('danh sách cận kề dùng cho chip điều hướng', () {
      final g = build();
      expect(g.prerequisitesOf('api'), {'json'});
      expect(g.dependentsOf('api'), {'spa', 'rest'});
    });

    test('node cô lập chỉ có chính nó', () {
      expect(build().branchOf('lan_dau'), {'lan_dau'});
    });
  });
}
