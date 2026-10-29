import 'dart:typed_data';

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

/// Levenshtein chỉ tính đúng tới `maxDist`: một con đường có tổng <= maxDist không
/// bao giờ lệch khỏi đường chéo quá maxDist cột, nên ô ngoài dải đó không cần xét;
/// cả dải mà min đã vượt ngưỡng thì kết luận "trượt" ngay. Hai chuỗi không liên
/// quan nhau — trường hợp của gần như toàn bộ kho mỗi lần gõ — chết sau vài hàng
/// thay vì dựng đủ bảng O(n*m).
///
/// Trả về `maxDist + 1` khi khoảng cách thật lớn hơn maxDist; người gọi có cutoff
/// chỉ cần biết là trượt, không cần con số chính xác.
int _levenshteinUnder(String a, String b, int maxDist) {
  final n = a.length, m = b.length;
  if ((n - m).abs() > maxDist) return maxDist + 1;

  final tooFar = maxDist + 1;
  var prev = List<int>.filled(m + 1, tooFar);
  var curr = List<int>.filled(m + 1, tooFar);
  var plo = 0;
  var phi = m < maxDist ? m : maxDist;
  for (var j = plo; j <= phi; j++) {
    prev[j] = j;
  }

  for (var i = 1; i <= n; i++) {
    final lo = i - maxDist > 0 ? i - maxDist : 0;
    final hi = i + maxDist < m ? i + maxDist : m;
    var rowMin = tooFar;

    for (var j = lo; j <= hi; j++) {
      if (j == 0) {
        curr[0] = i;
        if (i < rowMin) rowMin = i;
        continue;
      }
      final left = j > lo ? curr[j - 1] : tooFar;
      final up = j <= phi ? prev[j] : tooFar;
      final diagonal = (j - 1 >= plo && j - 1 <= phi) ? prev[j - 1] : tooFar;
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;

      var v = left + 1;
      if (up + 1 < v) v = up + 1;
      if (diagonal + cost < v) v = diagonal + cost;
      curr[j] = v;
      if (v < rowMin) rowMin = v;
    }

    if (rowMin > maxDist) return tooFar;

    final swap = prev;
    prev = curr;
    curr = swap;
    plo = lo;
    phi = hi;
  }

  return (m >= plo && m <= phi) ? prev[m] : tooFar;
}

/// Điểm tương đồng 0..1 giữa hai chuỗi đã chuẩn hóa.
///
/// `cutoff` là ngưỡng người dùng sẽ lọc kết quả. Khi có cutoff, hàm được phép bỏ
/// qua ứng viên chứng minh là không lọt ngưỡng mà không dựng bảng, và trả 0 thay
/// cho điểm dưới ngưỡng.
double similarity(String needle, String candidate, {double cutoff = 0}) =>
    similarityProfiled(profileOf(needle), profileOf(candidate), cutoff: cutoff);

/// Như [similarity] nhưng nhận hồ sơ ký tự dựng sẵn: toàn bộ kho được [profileOf]
/// một lần khi nạp, nên mỗi lần gõ chỉ còn vài phép cộng trên bộ đếm.
double similarityProfiled(CharProfile needle, CharProfile candidate, {required double cutoff}) {
  if (needle.length == 0 || candidate.length == 0) return 0;
  if (candidate.text == needle.text) return 1;
  if (candidate.text.contains(needle.text)) {
    return 0.9 + 0.1 * (needle.length / candidate.length);
  }

  final maxLen = needle.length > candidate.length ? needle.length : candidate.length;

  if (cutoff <= 0) {
    final score = 1 - levenshtein(needle.text, candidate.text) / maxLen;
    return score < 0 ? 0 : score;
  }

  // Hai cận dưới của Levenshtein: hiệu độ dài, và maxLen trừ đi số ký tự chung.
  // Lấy cận lớn hơn rồi suy ra cận trên của điểm — đủ để loại ứng viên miễn phí.
  final byLength = (needle.length - candidate.length).abs();
  final byLetters = maxLen - needle.sharedUpperBound(candidate);
  final minDist = byLength > byLetters ? byLength : byLetters;
  if (1 - minDist / maxLen < cutoff) return 0;

  final maxDist = ((1 - cutoff) * maxLen).floor();
  final score = 1 - _levenshteinUnder(needle.text, candidate.text, maxDist) / maxLen;
  return score < cutoff ? 0 : score;
}

const int _bucketCount = 37;
const int _otherBucket = 36;

/// Hồ sơ ký tự của một chuỗi đã chuẩn hóa: số lần mỗi chữ cái a-z và chữ số 0-9,
/// cộng một ô gom mọi ký tự khác (tiếng Việt có dấu).
///
/// Ô gom chỉ ước lượng THỪA số ký tự chung nên vẫn an toàn cho cận dưới của khoảng
/// cách, đổi lại không cần bảng 65.000 phần tử cho Unicode.
CharProfile profileOf(String value) {
  final counts = Uint8List(_bucketCount);
  for (final unit in value.codeUnits) {
    final bucket = _bucketOf(unit);
    if (counts[bucket] < 255) counts[bucket]++;
  }

  final present = <int>[];
  for (var i = 0; i < _bucketCount; i++) {
    if (counts[i] != 0) present.add(i);
  }
  return CharProfile._(value, counts, present);
}

class CharProfile {
  const CharProfile._(this.text, this._counts, this._present);

  final String text;
  final Uint8List _counts;
  final List<int> _present;

  int get length => text.length;

  /// Cận trên của số ký tự chung theo bộ đa: tổng min theo từng ô. Chuỗi con chung
  /// dài nhất không thể dài hơn, và mỗi sửa đổi chỉ thêm được một ký tự vào phần
  /// chung, nên `dist >= maxLen - sharedUpperBound(other)`.
  int sharedUpperBound(CharProfile other) {
    var sum = 0;
    for (final bucket in _present) {
      final theirs = other._counts[bucket];
      if (theirs == 0) continue;
      final mine = _counts[bucket];
      sum += mine < theirs ? mine : theirs;
    }
    return sum;
  }
}

int _bucketOf(int codeUnit) {
  if (codeUnit >= 97 && codeUnit <= 122) return codeUnit - 97;
  if (codeUnit >= 65 && codeUnit <= 90) return codeUnit - 65;
  if (codeUnit >= 48 && codeUnit <= 57) return 26 + codeUnit - 48;
  return _otherBucket;
}
