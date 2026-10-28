import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/trust.dart';

void main() {
  group('corroboratedConfidence (SRS mục 4, issue #8)', () {
    test('cộng 4 điểm cho mỗi nguồn độc lập phụ', () {
      expect(corroboratedConfidence(95, 1), 95);
      expect(corroboratedConfidence(95, 2), 99);
      expect(corroboratedConfidence(88, 3), 96);
    });

    test('trần 100 và không trừ khi chỉ một nguồn', () {
      expect(corroboratedConfidence(95, 9), 100);
      expect(corroboratedConfidence(80, 0), 80);
    });
  });
}
