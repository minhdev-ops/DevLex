import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// FR-GLOS-01 hứa "tức thì < 50ms" và issue #3 hứa kho đóng gói sẵn trong app.
/// Test này chạy trên chính asset mà người dùng nhận, nên nó là bằng chứng cho cả
/// hai: nếu corpus phình lên làm search chậm, đây là chỗ báo đỏ.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final Directory dir;
  late final int seedMs;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('glossary_scale_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);

    final sw = Stopwatch()..start();
    await GlossaryRepository.instance.warmUp();
    seedMs = sw.elapsedMilliseconds;
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  test('kho đóng gói mang đủ dữ liệu nguồn cho lần mở đầu tiên', () {
    expect(GlossaryRepository.instance.termCount, greaterThanOrEqualTo(6000));
    // Seed là chi phí chỉ trả một lần lúc cài; giữ nó trong giới hạn dễ chịu.
    expect(seedMs, lessThan(60000));
  });

  test('tra cứu trên toàn kho vẫn dưới 50ms cho từng kiểu truy vấn', () {
    // Lần quét đầu tiên trong isolate còn phải trả tiền JIT cho cả đường dẫn,
    // nên đo riêng nó với ngưỡng rộng; con số <50ms của FR-GLOS-01 là độ trễ
    // khi người dùng gõ phím, tức trạng thái nóng.
    final cold = Stopwatch()..start();
    GlossaryRepository.instance.search('api');
    cold.stop();
    expect(cold.elapsedMilliseconds, lessThan(400), reason: 'lần quét nguội chậm bất thường');

    const queries = [
      'api', // acronym ngắn
      'kubernetes', // khớp chính xác tên dài
      'firewall', // khớp một phần
      'load banancer', // sai chính tả, bắt buộc fuzzy
      'zero trust', // nhiều từ
      'giao thức', // tiếng Việt có dấu: mọi ứng viên đều "ngoài bảng" ASCII
      'chưa dịch', // tiếng Việt
      'zzzzq', // không có kết quả
      'c', // một ký tự, trường hợp tệ nhất về số ứng viên
    ];

    // Chạy song song với test khác thì số đo tường thuật còn gồm cả phần CPU bị
    // isolate khác cướp, không phản ánh chi phí thuật toán. Lấy ba lần đo: min là
    // chi phí quét thật (điều FR-GLOS-01 hứa), median chặn suy thoái hệ thống.
    for (final query in queries) {
      final timings = List<int>.generate(3, (_) => _timeSearch(query))..sort();
      expect(timings.first, lessThan(50), reason: 'query "$query" chậm');
      expect(timings[1], lessThan(120), reason: 'query "$query" median chậm bất thường');
      if (query == 'api' || query == 'kubernetes' || query == 'giao thức') {
        expect(GlossaryRepository.instance.search(query), isNotEmpty,
            reason: 'query "$query" phải có kết quả');
      }
      if (query == 'zzzzq') {
        expect(GlossaryRepository.instance.search(query), isEmpty);
      }
    }
  });

  test('API ở ba nguồn gộp thành một kết quả, bản có tên tiếng Việt thắng', () {
    final results = GlossaryRepository.instance.search('api');

    final api = results.where((r) => r.term.concept == 'applicationprogramminginterface').toList();
    expect(api, hasLength(1), reason: 'MDN, RFC và bản biên soạn không được chiếm ba dòng');
    expect(api.single.term.fullNameVi, isNotEmpty);
    expect(api.single.siblingCount, greaterThanOrEqualTo(2));
  });

  test('gõ sai một ký tự vẫn tới được thuật ngữ vận hành cốt lõi', () {
    final typo = GlossaryRepository.instance.search('load banancer');
    expect(typo.map((r) => r.term.acronym), contains('Load Balancer'));

    final graphql = GlossaryRepository.instance.search('graphql');
    expect(graphql, isNotEmpty);
    expect(graphql.first.term.fullNameVi, isNotEmpty);
  });

  test('từ khóa tiếng Việt tìm đúng mục từ đã dịch, không bị thuật ngữ Anh chen mất', () {
    final results = GlossaryRepository.instance.search('giao thức truyền tải');

    expect(results, isNotEmpty);
    expect(results.first.term.fullNameVi, isNotEmpty);
  });

  test('highlight của Context Decoder tra acronym trong kho lớn vẫn tức thì', () {
    final sw = Stopwatch()..start();
    expect(GlossaryRepository.instance.findByAcronymExact('K8s'), isNotNull);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
}

int _timeSearch(String query) {
  final sw = Stopwatch()..start();
  GlossaryRepository.instance.search(query);
  sw.stop();
  return sw.elapsedMilliseconds;
}
