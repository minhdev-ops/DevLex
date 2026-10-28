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
      'chưa dịch', // tiếng Việt
      'zzzzq', // không có kết quả
      'c', // một ký tự, trường hợp tệ nhất về số ứng viên
    ];

    for (final query in queries) {
      final sw = Stopwatch()..start();
      final results = GlossaryRepository.instance.search(query);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'query "$query" chậm');
      if (query == 'api' || query == 'kubernetes') {
        expect(results, isNotEmpty, reason: 'query "$query" phải có kết quả');
      }
      if (query == 'zzzzq') {
        expect(results, isEmpty);
      }
    }
  });

  test('highlight của Context Decoder tra acronym trong kho lớn vẫn tức thì', () {
    final sw = Stopwatch()..start();
    expect(GlossaryRepository.instance.findByAcronymExact('K8s'), isNotNull);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
}
