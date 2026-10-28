import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/sync_normalizer.dart';
import 'package:it_glossary/data/models/term.dart';

void main() {
  group('SyncNormalizer (Delta Sync #9)', () {
    final sample = <String, dynamic>{
      'status': 'success',
      'sync_timestamp': 1730000000,
      'changes': {
        'updated': [
          {
            'id': 'md_api',
            'tier_1': {
              'acronym': 'API',
              'full_name_en': 'Application Programming Interface',
              'full_name_vi': '',
              'short_definition': 'Quy tắc để các ứng dụng giao tiếp.',
            },
            'tier_2': {'detailed_explanation': 'API là cầu nối…', 'metaphor_analogy': null, 'diagram_url': null},
            'tier_3': {
              'category_tags': ['Backend'],
              'difficulty_level': 'Beginner',
              'prerequisites': ['term_http_002'],
              'related_terms': [],
            },
            'source_attribution': [
              {'component': 'tier_1', 'source': 'MDN Web Docs', 'author': 'Mozilla', 'license': 'CC BY-SA 2.5', 'authority_tier': 1, 'confidence': 88},
            ],
          },
        ],
        'deleted_ids': ['md_old_1', 'md_old_2'],
      },
    };

    test('chuẩn hóa nested snake -> flat camelCase + mốc thời gian', () {
      final r = SyncNormalizer.normalize(sample);
      expect(r.serverTimestamp, 1730000000);
      expect(r.deletedIds, ['md_old_1', 'md_old_2']);
      expect(r.rows.single['acronym'], 'API');
      expect(r.rows.single['fullNameEn'], 'Application Programming Interface');
      expect(r.rows.single['relatedTerms'], isEmpty);
    });

    test('row chuẩn hóa nạp được vào Term.fromJson', () {
      final r = SyncNormalizer.normalize(sample);
      final term = Term.fromJson(r.rows.single);
      expect(term.id, 'md_api');
      expect(term.prerequisites, ['term_http_002']);
      expect(term.attribution.single.confidence, 88);
      expect(term.attribution.single.isVerified, isTrue);
    });

    test('khóa concept đi kèm để gom ngữ cảnh offline (issue #8)', () {
      final withConcept = <String, dynamic>{
        ...sample,
        'changes': {
          'updated': [
            {
              ...(sample['changes'] as Map<String, dynamic>)['updated']!.first as Map<String, dynamic>,
              'concept': 'applicationprogramminginterface',
            },
          ],
          'deleted_ids': [],
        },
      };
      final r = SyncNormalizer.normalize(withConcept);
      expect(r.rows.single['concept'], 'applicationprogramminginterface');
      expect(Term.fromJson(r.rows.single).concept, 'applicationprogramminginterface');
    });

    test('payload rỗng an toàn', () {
      final r = SyncNormalizer.normalize({'changes': {}});
      expect(r.rows, isEmpty);
      expect(r.deletedIds, isEmpty);
      expect(r.serverTimestamp, 0);
      expect(r.hasMore, isFalse);
      expect(r.nextCursor, isNull);
    });

    test('đọc con trỏ lô (keyset pagination) từ payload', () {
      final paged = <String, dynamic>{
        ...sample,
        'has_more': true,
        'next_cursor': 'eyJ0IjoxNzMwMDAwMDAwLCJpIjoibWRfYXBpIn0=',
      };
      final r = SyncNormalizer.normalize(paged);
      expect(r.hasMore, isTrue);
      expect(r.nextCursor, 'eyJ0IjoxNzMwMDAwMDAwLCJpIjoibWRfYXBpIn0=');
    });
  });
}
