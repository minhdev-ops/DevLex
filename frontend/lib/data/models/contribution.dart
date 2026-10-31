/// Một đề xuất đóng góp trong hàng chờ kiểm duyệt (FR-COMM-01/02).
///
/// Khớp payload của `GET /api/v1/contributions` (backend Laravel): các trường
/// giữ nguyên tên snake_case của server để không phải ánh xạ hai chiều.
class Contribution {
  const Contribution({
    required this.id,
    required this.status,
    required this.contributorName,
    required this.acronym,
    required this.fullNameEn,
    required this.shortDefinition,
    this.detailedExplanation,
    this.reviewNote,
    this.createdAt,
  });

  final String id;
  final String status;
  final String contributorName;
  final String acronym;
  final String fullNameEn;
  final String shortDefinition;
  final String? detailedExplanation;
  final String? reviewNote;
  final DateTime? createdAt;

  static const statusPending = 'pending';
  static const statusApproved = 'approved';
  static const statusRejected = 'rejected';

  bool get isPending => status == statusPending;

  factory Contribution.fromJson(Map<String, dynamic> json) {
    return Contribution(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? statusPending).toString(),
      contributorName: (json['contributor_name'] ?? '').toString(),
      acronym: (json['tier_1_acronym'] ?? '').toString(),
      fullNameEn: (json['tier_1_full_name_en'] ?? '').toString(),
      shortDefinition: (json['tier_1_short_definition'] ?? '').toString(),
      detailedExplanation: json['tier_2_detailed_explanation'] as String?,
      reviewNote: json['review_note'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  String get statusLabel => switch (status) {
    statusApproved => 'Đã duyệt',
    statusRejected => 'Từ chối',
    _ => 'Chờ duyệt',
  };
}
