import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_glossary/core/auto_sync.dart';
import 'package:it_glossary/data/api_client.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/clear_packaged_corpus.dart';

/// Trang delta rỗng nhưng hợp lệ: đủ để syncNow chạy hết một vòng.
String _emptyPage() => jsonEncode({
  'status': 'success',
  'sync_timestamp': 1700000000,
  'has_more': false,
  'next_cursor': null,
  'changes': {'updated': <dynamic>[], 'deleted_ids': <dynamic>[]},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  final repo = GlossaryRepository.instance;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('auto_sync_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await clearPackagedCorpus();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  ApiClient client({
    void Function()? onCall,
    Duration delay = Duration.zero,
  }) => ApiClient(
    baseUrl: 'http://api.test',
    client: MockClient((req) async {
      onCall?.call();
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return http.Response(
        _emptyPage(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  Future<void> setCursor(DateTime at) =>
      GlossaryDatabase.instance.setSyncCursor(at.millisecondsSinceEpoch ~/ 1000);

  test('chưa từng đồng bộ thì tự kéo delta ngay', () async {
    await GlossaryDatabase.instance.setSyncCursor(0);
    var calls = 0;

    final outcome = await AutoSync().maybeSync(
      api: client(onCall: () => calls++),
      repository: repo,
    );

    expect(calls, 1);
    expect(outcome, isNotNull);
    expect(outcome!.ok, isTrue);
    expect(await repo.lastSyncAt(), isNotNull);
  });

  test('dữ liệu còn mới hơn ngưỡng thì bỏ qua, không gọi mạng', () async {
    await setCursor(DateTime.now());
    var calls = 0;

    final outcome = await AutoSync().maybeSync(
      api: client(onCall: () => calls++),
      repository: repo,
    );

    expect(calls, 0);
    expect(outcome, isNull);
  });

  test('quá ngưỡng thì đồng bộ lại', () async {
    await setCursor(DateTime.now().subtract(const Duration(hours: 7)));
    var calls = 0;

    final outcome = await AutoSync(maxAge: const Duration(hours: 6)).maybeSync(
      api: client(onCall: () => calls++),
      repository: repo,
    );

    expect(calls, 1);
    expect(outcome!.ok, isTrue);
  });

  test('force bỏ qua ngưỡng tuổi dữ liệu', () async {
    await setCursor(DateTime.now());
    var calls = 0;

    final outcome = await AutoSync().maybeSync(
      force: true,
      api: client(onCall: () => calls++),
      repository: repo,
    );

    expect(calls, 1);
    expect(outcome!.ok, isTrue);
  });

  test('không chạy chồng: lần gọi thứ hai trả null ngay', () async {
    await GlossaryDatabase.instance.setSyncCursor(0);
    var calls = 0;
    final sync = AutoSync();
    final api = client(
      onCall: () => calls++,
      delay: const Duration(milliseconds: 80),
    );

    final first = sync.maybeSync(api: api, repository: repo);
    final second = await sync.maybeSync(api: api, repository: repo);
    final firstOutcome = await first;

    expect(second, isNull);
    expect(firstOutcome, isNotNull);
    expect(calls, 1);
    expect(sync.running, isFalse);
  });
}
