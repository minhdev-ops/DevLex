String normalizeQuery(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_.,/]+'), '')
      .trim();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = curr[j - 1] + 1;
      if (prev[j] + 1 < v) v = prev[j] + 1;
      if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
      curr[j] = v;
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

double similarity(String needle, String candidate, {double cutoff = 0}) {
  if (needle.isEmpty || candidate.isEmpty) return 0;
  if (candidate == needle) return 1;
  if (candidate.startsWith(needle) || candidate.contains(needle)) {
    return 0.9 + 0.1 * (needle.length / candidate.length);
  }

  final maxLen = needle.length > candidate.length ? needle.length : candidate.length;
  final minLen = needle.length < candidate.length ? needle.length : candidate.length;

  // Levenshtein không bao giờ nhỏ hơn hiệu độ dài, nên biểu thức dưới là cận trên
  // của điểm. Vượt qua bước này mới đáng tốn O(n*m) để dựng bảng — nhờ đó toàn bộ
  // kho >6.000 mục từ vẫn quét được trong ngưỡng <50ms của FR-GLOS-01.
  if (cutoff > 0 && 1 - (maxLen - minLen) / maxLen < cutoff) return 0;

  final shared = _sharedLetters(needle, candidate);
  if (cutoff > 0 && shared != null && 1 - (maxLen - shared) / maxLen < cutoff) return 0;

  final dist = levenshtein(needle, candidate);
  final score = 1 - dist / maxLen;
  return score < 0 ? 0 : score;
}

/// Số chữ cái chung (theo tập, không tính lặp) giữa hai chuỗi, hoặc null nếu có
/// ký tự ngoài a-z/A-Z/0-9 — ví dụ tiếng Việt có dấu — khi đó không có cận tin cậy.
///
/// Mỗi một sửa đổi chỉ thêm được tối đa một chữ cái vào phần chung, nên
/// `dist >= maxLen - shared`: đây là cận trên miễn phí của điểm, cắt gần hết số
/// lần phải dựng bảng Levenshtein khi quét cả kho.
int? _sharedLetters(String a, String b) {
  final maskA = _letterMask(a);
  if (maskA == null) return null;
  final maskB = _letterMask(b);
  if (maskB == null) return null;

  var common = 0;
  for (var inter = maskA & maskB; inter != 0; inter &= inter - 1) {
    common++;
  }
  return common;
}

int? _letterMask(String value) {
  var mask = 0;
  for (final unit in value.codeUnits) {
    if (unit >= 97 && unit <= 122) {
      mask |= 1 << (unit - 97);
    } else if (unit >= 65 && unit <= 90) {
      mask |= 1 << (unit - 65);
    } else if (unit >= 48 && unit <= 57) {
      mask |= 1 << (26 + unit - 48);
    } else {
      return null;
    }
  }
  return mask;
}
