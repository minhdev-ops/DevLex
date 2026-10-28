import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/models/term.dart';

Term term({required String vi}) => Term(
      id: 'rfc_acl',
      acronym: 'ACL',
      fullNameEn: 'access control list',
      fullNameVi: vi,
      shortDefinition: 'Danh sách quy định quyền truy cập.',
      detailedExplanation: null,
      metaphorAnalogy: null,
      diagramUrl: null,
      categoryTags: const [],
      difficulty: 'Beginner',
      prerequisites: const [],
      relatedTerms: const [],
      career: null,
      attribution: const [],
    );

void main() {
  group('trạng thái chờ dịch (issue #1)', () {
    test('mục từ chưa dịch hiện "chờ dịch", không bỏ dấu — treo', () {
      final t = term(vi: '');
      expect(t.needsTranslation, isTrue);
      expect(t.bilingualName, 'access control list · chờ dịch');
    });

    test('mục từ đã dịch hiện song ngữ', () {
      final t = term(vi: 'danh sách kiểm soát truy cập');
      expect(t.needsTranslation, isFalse);
      expect(t.bilingualName, 'access control list — danh sách kiểm soát truy cập');
    });
  });
}
