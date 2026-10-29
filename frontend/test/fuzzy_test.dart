import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:it_glossary/core/fuzzy.dart';

void main() {
  group('normalizeQuery', () {
    test('bỏ khoảng trắng và ký tự phân cách, về chữ thường', () {
      expect(normalizeQuery('CI/CD'), 'cicd');
      expect(normalizeQuery(' K8s '), 'k8s');
    });
  });

  group('similarity', () {
    test('khớp chính xác = 1', () {
      expect(similarity('api', 'api'), 1.0);
    });

    test('khớp tiền tố cao hơn khớp xa', () {
      expect(similarity('kube', 'kubernetes'), greaterThan(similarity('dock', 'kubernetes')));
    });

    test('gõ sai nhẹ vẫn đạt điểm cao (Levenshtein)', () {
      expect(similarity('kubernets', 'kubernetes'), greaterThanOrEqualTo(0.8));
    });

    test('cutoff bỏ ứng viên không thể đạt ngưỡng mà không dựng bảng', () {
      // 'acl' vs chuỗi 17 ký tự: cận trên của điểm đã là 0.18, dưới ngưỡng 0.55.
      expect(similarity('acl', 'accesscontrollist'), lessThan(0.55));
      expect(similarity('acl', 'accesscontrollist', cutoff: 0.55), 0);
    });

    test('cutoff không được cắt mất ứng viên xứng đáng xuất hiện', () {
      expect(similarity('kubernets', 'kubernetes', cutoff: 0.55), greaterThanOrEqualTo(0.8));
      expect(similarity('firewl', 'firewall', cutoff: 0.55), greaterThan(0.55));
      expect(similarity('api', 'api', cutoff: 0.55), 1.0);
    });

    test('cutoff không cắt oan từ khóa tiếng Việt có dấu', () {
      // Cận trên dựa trên ký tự chung phải tính cả phần ngoài bảng ASCII, nếu không
      // mọi truy vấn có dấu sẽ bị bỏ qua và tìm tiếng Việt trả về 0 kết quả.
      final needle = normalizeQuery('may chutinh');
      final candidate = normalizeQuery('máy chủ tính');

      expect(similarity(needle, candidate, cutoff: 0.55), greaterThan(0.55));
    });

    test('phần chung tính theo số lần xuất hiện, không theo tập ký tự', () {
      // '50ss' vs 'ss': cả hai chữ s đều khớp -> khoảng cách 2, điểm 0.5. Đếm theo
      // tập ký tự sẽ ra 1 và cắt mất kết quả này.
      expect(similarity('50ss', 'ss', cutoff: 0.4), closeTo(0.5, 1e-9));
    });

    test('bản dừng sớm cho điểm giống Levenshtein đầy đủ trên mọi cặp ngẫu nhiên', () {      final random = Random(7);
      const alphabet = 'abcdeijklmnoprstuvxy0123456789';

      String word(int maxLen) {
        final length = 1 + random.nextInt(maxLen);
        return List.generate(length, (_) => alphabet[random.nextInt(alphabet.length)]).join();
      }

      for (var i = 0; i < 400; i++) {
        final needle = word(12);
        final candidate = word(12);
        if (needle == candidate || candidate.contains(needle)) continue;

        final maxLen = needle.length > candidate.length ? needle.length : candidate.length;
        final exact = 1 - levenshtein(needle, candidate) / maxLen;

        for (final cutoff in [0.4, 0.55, 0.7, 0.85]) {
          expect(
            similarity(needle, candidate, cutoff: cutoff),
            exact < cutoff ? 0 : closeTo(exact, 1e-9),
            reason: 'cặp "$needle" / "$candidate" với cutoff $cutoff',
          );
        }
      }
    });
  });

  test('levenshtein cơ bản', () {
    expect(levenshtein('kitten', 'sitting'), 3);
    expect(levenshtein('', 'abc'), 3);
  });
}
