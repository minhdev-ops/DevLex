import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_glossary/data/api_client.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/detail/term_detail_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Một dòng delta sync đúng hình API (/api/v1/sync/delta).
Map<String, dynamic> apiRow({
  required String id,
  required String acronym,
  required String name,
  required String concept,
  required String source,
  required int confidence,
}) =>
    {
      'id': id,
      'tier_1': {
        'acronym': acronym,
        'full_name_en': name,
        'full_name_vi': '',
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
          'source': source,
          'author': 'Ban biên soạn',
          'license': 'Public Domain',
          'authority_tier': 1,
          'confidence': confidence,
        },
      ],
      'roadmap_career': null,
      'concept': concept,
    };

Map<String, dynamic> page(List<Map<String, dynamic>> rows, {required bool hasMore, String? nextCursor}) => {
      'status': 'success',
      'sync_timestamp': 1700000000,
      'has_more': hasMore,
      'next_cursor': nextCursor,
      'changes': {'updated': rows, 'deleted_ids': []},
    };

final rfcAcl = apiRow(
  id: 'rfc_acl',
  acronym: 'ACL',
  name: 'access control list',
  concept: 'accesscontrollist',
  source: 'RFC 4949',
  confidence: 93,
);

final mdnAcl = apiRow(
  id: 'mdn_acl',
  acronym: 'ACL',
  name: 'access control list',
  concept: 'accesscontrollist',
  source: 'MDN Web Docs',
  confidence: 88,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('glossary_sync_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  // I/O thật (asset seed, SQLite, HTTP) chỉ chạy được ngoài zone fake-async
  // của testWidgets, nên phần dữ liệu để trong test() thường.
  test('delta sync nhiều lô: kéo hết trang, ghi SQLite, nạp lại cache', () async {
    final requestedCursors = <String?>[];
    final mock = MockClient((request) async {
      final cursor = request.url.queryParameters['cursor'];
      requestedCursors.add(cursor);

      return http.Response(
        jsonEncode(cursor == null
            ? page([rfcAcl], hasMore: true, nextCursor: 'CURSOR_HAI')
            : page([mdnAcl], hasMore: false)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = GlossaryRepository.instance;
    final outcome = await repo.syncNow(api: ApiClient(baseUrl: 'http://test', client: mock));

    expect(requestedCursors, [null, 'CURSOR_HAI'],
        reason: 'phải kéo hết số lô cho tới khi next_cursor rỗng');
    expect(outcome.ok, isTrue);
    expect(outcome.updated, 2);
    expect(await GlossaryDatabase.instance.getSyncCursor(), 1700000000);

    final term = repo.termById('rfc_acl')!;
    expect(term.concept, 'accesscontrollist',
        reason: 'cột concept phải sống sót qua vòng ghi/nạp SQLite');

    final trust = repo.trustFor(term);
    expect(trust.contexts.single.id, 'mdn_acl');
    expect(trust.agreeingSources, containsAll(<String>['RFC 4949', 'MDN Web Docs']));
    expect(trust.confidence, 97, reason: '= 93 + 4 cho mỗi nguồn độc lập phụ (trần 100)');
  });

  testWidgets('màn chi tiết hiển thị mức tin cậy đa nguồn (offline)', (tester) async {
    // Kế thừa DB + cache in-memory mà test() ở trên đã nạp: singleton
    // GlossaryRepository/GlossaryDatabase không có seam để thế cache khác,
    // còn gọi warmUp() trong testWidgets sẽ kẹt vì I/O thật + zone fake async.
    await tester.pumpWidget(const MaterialApp(home: TermDetailScreen(termId: 'rfc_acl')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mức tin cậy'), findsOneWidget);
    expect(find.textContaining('2 nguồn độc lập'), findsOneWidget);
    expect(find.textContaining('97/100'), findsWidgets);
    // Dòng sync về chưa dịch -> báo trạng thái chứ không để tên tiếng Việt trống.
    expect(find.textContaining('Chưa có bản dịch tiếng Việt'), findsOneWidget);
  });
}
