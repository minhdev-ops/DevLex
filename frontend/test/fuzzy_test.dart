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
  });

  test('levenshtein cơ bản', () {
    expect(levenshtein('kitten', 'sitting'), 3);
    expect(levenshtein('', 'abc'), 3);
  });
}
