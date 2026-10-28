import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_glossary/data/api_client.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Một mục từ cùng khái niệm nhưng khác nguồn: server giữ hai dòng riêng,
/// người dùng chỉ muốn thấy một kết quả.
Map<String, dynamic> row({
  required String id,
  required String acronym,
  required String name,
  String vi = '',
  String? concept,
  required int confidence,
}) =>
    {
      'id': id,
      'tier_1': {
        'acronym': acronym,
        'full_name_en': name,
        'full_name_vi': vi,
        'short_definition': '$name — định nghĩa ngắn.',
      },
      'tier_2': {'detailed_explanation': null, 'metaphor_analogy': null, 'diagram_url': null},
      'tier_3': {
        'category_tags': <String>[],
        'difficulty_level': 'Beginner',
        'prerequisites': <String>[],
        'related_terms': <String>[],
      },
      'source_attribution': [
        {
          'component': 'tier_1',
          'source': 'MDN Web Docs',
          'author': 'Ban biên soạn',
          'license': 'CC BY-SA 2.0',
          'authority_tier': 1,
          'confidence': confidence,
        },
      ],
      'roadmap_career': null,
      'concept': concept,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('search_collapse_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);

    final rows = <Map<String, dynamic>>[
      row(id: 'mdn_api', acronym: 'API', name: 'Application Programming Interface',
          concept: 'applicationprogramminginterface', confidence: 88),
      row(id: 'rfc_api', acronym: 'API', name: 'Application programming interface', vi: 'Giao diện lập trình ứng dụng',
          concept: 'applicationprogramminginterface', confidence: 93),
      row(id: 'nist_ath', acronym: 'ATH', name: 'advanced thread handler',
          concept: 'advancedthreadhandler', confidence: 95),
      row(id: 'legacy_api', acronym: 'API', name: 'Application Programming Interface',
          concept: 'applicationprogramminginterface', confidence: 70),
      // không có concept (đóng góp cộng đồng, mục từ cũ) -> không được gộp với ai
      row(id: 'curated_jwt', acronym: 'JWT', name: 'JSON Web Token', confidence: 60),
    ];

    final repo = GlossaryRepository.instance;
    await repo.syncNow(
      api: ApiClient(
        baseUrl: 'http://test',
        client: MockClient((req) async => http.Response(
              jsonEncode({
                'status': 'success',
                'sync_timestamp': 1700000000,
                'has_more': false,
                'next_cursor': null,
                'changes': {'updated': rows, 'deleted_ids': []},
              }),
              200,
              headers: {'content-type': 'application/json'},
            )),
      ),
    );
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  test('ba dòng cùng concept chỉ còn một kết quả, ưu tiên bản đã có tên Việt', () {
    final results = GlossaryRepository.instance.search('application programming interface');

    final hit = results.where((r) => r.term.concept == 'applicationprogramminginterface').toList();
    expect(hit, hasLength(1), reason: 'cùng khái niệm không được chiếm hai dòng kết quả');
    expect(hit.single.term.id, 'rfc_api', reason: 'bản có tên tiếng Việt phải thắng');
    expect(hit.single.siblingCount, 2, reason: 'hai dòng khác đã được gộp vào');
  });

  test('dòng không có concept vẫn xuất hiện riêng', () {
    final results = GlossaryRepository.instance.search('jwt');

    expect(results.map((r) => r.term.id), contains('curated_jwt'));
    expect(results.firstWhere((r) => r.term.id == 'curated_jwt').siblingCount, 0);
  });

  test('mỗi concept vẫn là một kết quả riêng', () {
    final results = GlossaryRepository.instance.search('advanced thread handler');

    expect(results, hasLength(1));
    expect(results.single.term.id, 'nist_ath');
    expect(results.single.siblingCount, 0);
  });
}
