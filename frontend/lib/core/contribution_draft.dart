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

  // Trùng với StoreContributionRequest ở backend để người dùng thấy lỗi ngay
  // trong form thay vì bị server trả 422 sau khi gửi.
  static const int maxShort = 2000;
  static const int maxName = 120;
  static const int maxAcronym = 100;
  static const int maxFullNameEn = 255;
  /// Giới hạn hiển thị trong form (chặt hơn mức 20.000 ký tự server cho phép
  /// để ô nhập còn dùng được trên điện thoại).
  static const int maxDetail = 4000;

  /// Trả về map tên-field -> lỗi (rỗng = hợp lệ).
  Map<String, String> validate() {
    final errors = <String, String>{};

    final name = contributorName.trim();
    if (name.length < 2) {
      errors['contributorName'] = 'Tên người đóng góp tối thiểu 2 ký tự.';
    } else if (name.length > maxName) {
      errors['contributorName'] = 'Tên người đóng góp tối đa $maxName ký tự.';
    }
    final acr = acronym.trim();
    if (acr.isEmpty) {
      errors['acronym'] = 'Từ viết tắt không được để trống.';
    } else if (acr.length > maxAcronym) {
      errors['acronym'] = 'Từ viết tắt tối đa $maxAcronym ký tự.';
    }
    final fullEn = fullNameEn.trim();
    if (fullEn.isEmpty) {
      errors['fullNameEn'] = 'Tên đầy đủ tiếng Anh không được để trống.';
    } else if (fullEn.length > maxFullNameEn) {
      errors['fullNameEn'] = 'Tên đầy đủ tiếng Anh tối đa $maxFullNameEn ký tự.';
    }
    final short = shortDefinition.trim();
    if (short.isEmpty) {
      errors['shortDefinition'] =
          'Định nghĩa ngắn (Tầng 1) không được để trống.';
    } else if (short.length > maxShort) {
      errors['shortDefinition'] = 'Định nghĩa ngắn tối đa $maxShort ký tự.';
    }
    if (detailedExplanation.trim().length > maxDetail) {
      errors['detailedExplanation'] =
          'Giải thích chi tiết tối đa $maxDetail ký tự.';
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
