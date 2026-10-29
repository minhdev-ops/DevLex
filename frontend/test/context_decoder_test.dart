import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/context_decoder.dart';

/// Lookup giả lập: khớp đúng các acronym trong [known], trả về id ổn định.
String? Function(String) lookupFor(Set<String> known) =>
    (token) => known.contains(token) ? 'term_$token' : null;

void main() {
  const decoder = ContextDecoder();

  group('ContextDecoder — FR-DEC-01', () {
    test('tokenize và khớp acronym, giữ ký tự phân cách', () {
      final result = decoder.decode(
        'Cần REST API, JWT nhé',
        lookupFor({'REST', 'API', 'JWT'}),
      );

      expect(result.truncated, isFalse);
      expect(result.matchCount, 3);
      expect(result.matchedTermIds, ['term_REST', 'term_API', 'term_JWT']);
      // Văn bản gốc tái tạo trung thực từ các token.
      expect(result.tokens.map((t) => t.text).join(), 'Cần REST API, JWT nhé');
    });

    test('token không khớp có termId null', () {
      final result = decoder.decode('chill thôi', lookupFor({'API'}));
      expect(result.matchCount, 0);
      expect(result.tokens.every((t) => !t.isMatch), isTrue);
    });

    test('từ tiếng Việt có dấu giữ nguyên một token, không lộ chữ cái đơn', () {
      final result = decoder.decode(
        'Cần tuyển vị trí',
        lookupFor({'C', 'n', 'v', 't', 'u', 'bi'}),
      );

      expect(result.matchCount, 0, reason: '"Cần" không được cắt thành "C" + "n"');
      expect(result.tokens.map((t) => t.text).first, 'Cần');
      expect(result.tokens.map((t) => t.text).join(), 'Cần tuyển vị trí');
    });

    test('văn bản đúng ngưỡng 10.000 ký tự không bị cắt', () {
      final text = 'a' * 10000;
      final result = decoder.decode(text, lookupFor({'a'}));
      expect(result.truncated, isFalse);
      expect(result.originalLength, 10000);
      expect(result.tokens.map((t) => t.text).join().length, 10000);
    });

    test('văn bản vượt 10.000 ký tự bị cắt và báo truncated', () {
      final text = 'x' * 12000;
      final result = decoder.decode(text, lookupFor({'x'}));
      expect(result.truncated, isTrue);
      expect(result.originalLength, 12000);
      expect(result.tokens.map((t) => t.text).join().length, 10000);
    });

    test('chuỗi rỗng an toàn', () {
      final result = decoder.decode('', lookupFor({'API'}));
      expect(result.tokens, isEmpty);
      expect(result.matchCount, 0);
      expect(result.truncated, isFalse);
    });
  });
}
