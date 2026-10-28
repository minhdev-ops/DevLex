import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Đối chiếu dữ liệu seed với 4 bộ từ khóa sự nghiệp trong SRS mục 2.2.
void main() {
  late List<dynamic> terms;

  setUpAll(() {
    final raw = File('assets/seed/terms.json').readAsStringSync();
    terms = (jsonDecode(raw) as Map<String, dynamic>)['terms'] as List<dynamic>;
  });

  test('phủ đủ 4 career theo SRS 2.2 (mỗi career >= 5 thuật ngữ)', () {
    final byCareer = <String, int>{};
    for (final t in terms) {
      final career = t['career'] as String;
      byCareer[career] = (byCareer[career] ?? 0) + 1;
    }
    for (final career in ['frontend', 'backend', 'devops', 'project_comm']) {
      expect(byCareer[career] ?? 0, greaterThanOrEqualTo(5), reason: 'career $career thiếu thuật ngữ');
    }
  });

  test('chứa các acronym chủ chốt của từng lộ trình nghề nghiệp', () {
    final acronyms = terms.map((t) => (t['acronym'] as String).toLowerCase()).toSet();
    const required = [
      // frontend
      'html', 'css', 'dom', 'api', 'json', 'spa', 'ssr',
      // backend
      'rest', 'crud', 'sql', 'nosql', 'orm', 'middleware', 'jwt',
      // devops
      'ci/cd', 'docker', 'container', 'kubernetes', 'iaas', 'paas',
      // project communication
      'agile', 'scrum', 'sprint', 'pull request', 'code review', 'staging', 'hotfix',
    ];
    for (final r in required) {
      expect(acronyms, contains(r), reason: 'thiếu thuật ngữ bắt buộc: $r');
    }
  });

  test('không có tham trưng mồ côi ở prerequisites/relatedTerms', () {
    final ids = terms.map((t) => t['id'] as String).toSet();
    for (final t in terms) {
      final refs = <String>[
        ...(t['prerequisites'] as List<dynamic>? ?? []).cast<String>(),
        ...(t['relatedTerms'] as List<dynamic>? ?? []).cast<String>(),
      ];
      for (final r in refs) {
        expect(ids, contains(r), reason: '${t['id']} tham chiếu "$r" không tồn tại');
      }
    }
  });

  test('mọi thuật ngữ có attribution không rỗng (tuân thủ bản quyền)', () {
    for (final t in terms) {
      final attribution = t['attribution'] as List<dynamic>;
      expect(attribution, isNotEmpty, reason: '${t['id']} thiếu source_attribution');
    }
  });
}
