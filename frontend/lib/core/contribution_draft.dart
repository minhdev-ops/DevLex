/// Trạng thái + quy tắc kiểm dữ liệu cho một đề xuất đóng góp (FR-COMM-01).
/// Tách logic thuần để unit-test không cần mạng/DB.
class ContributionDraft {
  const ContributionDraft({
    this.contributorName = '',
    this.acronym = '',
    this.fullNameEn = '',
    this.shortDefinition = '',
    this.detailedExplanation = '',
  });

  final String contributorName;
  final String acronym;
  final String fullNameEn;
  final String shortDefinition;
  final String detailedExplanation;

  static const int maxShort = 2000;

  /// Trả về map tên-field -> lỗi (rỗng = hợp lệ).
  Map<String, String> validate() {
    final errors = <String, String>{};

    if (contributorName.trim().length < 2) {
      errors['contributorName'] = 'Tên người đóng góp tối thiểu 2 ký tự.';
    }
    if (acronym.trim().isEmpty) {
      errors['acronym'] = 'Từ viết tắt không được để trống.';
    }
    if (fullNameEn.trim().isEmpty) {
      errors['fullNameEn'] = 'Tên đầy đủ tiếng Anh không được để trống.';
    }
    final short = shortDefinition.trim();
    if (short.isEmpty) {
      errors['shortDefinition'] = 'Định nghĩa ngắn (Tầng 1) không được để trống.';
    } else if (short.length > maxShort) {
      errors['shortDefinition'] = 'Định nghĩa ngắn tối đa $maxShort ký tự.';
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  /// Body JSON khớp StoreContributionRequest ở backend.
  Map<String, dynamic> toJson() => {
        'contributor_name': contributorName.trim(),
        'tier_1_acronym': acronym.trim(),
        'tier_1_full_name_en': fullNameEn.trim(),
        'tier_1_short_definition': shortDefinition.trim(),
        if (detailedExplanation.trim().isNotEmpty)
          'tier_2_detailed_explanation': detailedExplanation.trim(),
      };
}
