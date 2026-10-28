/// Chấm điểm đồng thuận đa nguồn (SRS mục 4, issue #8).
/// Bản sao của backend `SourceRegistry::corroborate` để app offline báo đúng
/// cùng một con số mà API chi tiết trả về.
int corroboratedConfidence(int baseConfidence, int agreeingSources) {
  final extra = agreeingSources > 1 ? agreeingSources - 1 : 0;
  final score = baseConfidence + (4 * extra);

  return score > 100 ? 100 : score;
}
