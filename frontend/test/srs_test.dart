import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/glossary_repository.dart';

void main() {
  group('SRS ladder (FR-QUIZ-02)', () {
    test('bắt đầu -> 1 ngày', () {
      expect(nextIntervalDays(0), 1);
    });

    test('1 -> 3 -> 7 và giữ nguyên ở mức cao nhất', () {
      expect(nextIntervalDays(1), 3);
      expect(nextIntervalDays(3), 7);
      expect(nextIntervalDays(7), 7);
    });
  });
}
