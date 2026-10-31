import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/contribution_draft.dart';

void main() {
  group('ContributionDraft (FR-COMM-01)', () {
    test('bắt buộc tên >=2 ký tự và các trường Tầng 1', () {
      final draft = const ContributionDraft(contributorName: 'A');
      final errors = draft.validate();
      expect(errors['contributorName'], isNotNull);
      expect(errors['acronym'], isNotNull);
      expect(errors['fullNameEn'], isNotNull);
      expect(errors['shortDefinition'], isNotNull);
      expect(draft.isValid, isFalse);
    });

    test('draft hợp lệ cho toJson khớp backend', () {
      const draft = ContributionDraft(
        contributorName: '  Trần Minh  ',
        acronym: ' gRPC ',
        fullNameEn: 'gRPC Remote Procedure Call',
        shortDefinition: '  Framework RPC mã nguồn mở.  ',
        detailedExplanation: '',
      );
      expect(draft.isValid, isTrue);
      expect(draft.toJson(), {
        'contributor_name': 'Trần Minh',
        'tier_1_acronym': 'gRPC',
        'tier_1_full_name_en': 'gRPC Remote Procedure Call',
        'tier_1_short_definition': 'Framework RPC mã nguồn mở.',
      });
    });

    // Giới hạn phải trùng StoreContributionRequest, nếu lệch thì người dùng
    // điền xong mới bị server trả 422.
    test('chặn vượt độ dài mà backend quy định', () {
      final longName = ContributionDraft(
        contributorName: 'a' * (ContributionDraft.maxName + 1),
        acronym: 'API',
        fullNameEn: 'Application Programming Interface',
        shortDefinition: 'Quy tắc giao tiếp.',
      );
      expect(longName.validate()['contributorName'], isNotNull);

      final longAcronym = ContributionDraft(
        contributorName: 'Minh',
        acronym: 'A' * (ContributionDraft.maxAcronym + 1),
        fullNameEn: 'Application Programming Interface',
        shortDefinition: 'Quy tắc giao tiếp.',
      );
      expect(longAcronym.validate()['acronym'], isNotNull);

      final longFullName = ContributionDraft(
        contributorName: 'Minh',
        acronym: 'API',
        fullNameEn: 'A' * (ContributionDraft.maxFullNameEn + 1),
        shortDefinition: 'Quy tắc giao tiếp.',
      );
      expect(longFullName.validate()['fullNameEn'], isNotNull);

      final longDetail = ContributionDraft(
        contributorName: 'Minh',
        acronym: 'API',
        fullNameEn: 'Application Programming Interface',
        shortDefinition: 'Quy tắc giao tiếp.',
        detailedExplanation: 'x' * (ContributionDraft.maxDetail + 1),
      );
      expect(longDetail.validate()['detailedExplanation'], isNotNull);
    });

    test('không gửi trường giải thích rỗng', () {
      const draft = ContributionDraft(
        contributorName: 'Minh',
        acronym: 'API',
        fullNameEn: 'Application Programming Interface',
        shortDefinition: 'Quy tắc giao tiếp.',
        detailedExplanation: '   ',
      );
      expect(
        draft.toJson().containsKey('tier_2_detailed_explanation'),
        isFalse,
      );
    });
  });
}
