import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/api_config.dart';

void main() {
  group('ApiConfig.parse', () {
    test('chấp nhận http/https và bỏ dấu / ở cuối', () {
      expect(ApiConfig.parse('http://192.168.1.10:8000'), 'http://192.168.1.10:8000');
      expect(ApiConfig.parse('  https://api.devlex.vn/  '), 'https://api.devlex.vn');
      expect(ApiConfig.parse('http://10.0.2.2:8000///'), 'http://10.0.2.2:8000');
    });

    test('từ chối giá trị rỗng hoặc sai giao thức', () {
      expect(ApiConfig.parse(''), isNull);
      expect(ApiConfig.parse('   '), isNull);
      expect(ApiConfig.parse('ftp://example.com'), isNull);
      expect(ApiConfig.parse('192.168.1.10:8000'), isNull);
      expect(ApiConfig.parse('http://'), isNull);
    });
  });

  test('mặc định khác nhau giữa Android emulator và nền tảng khác', () {
    // Chỉ kiểm tra bất biến: luôn là URL http(s) tuyệt đối.
    final uri = Uri.parse(ApiConfig.defaultBaseUrl);
    expect(uri.hasScheme, isTrue);
    expect(uri.host, isNotEmpty);
  });
}
