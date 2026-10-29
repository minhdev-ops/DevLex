/// FR-DEC-01 logic tách riêng khỏi widget để kiểm thử được độc lập.
///
/// Nhận văn bản thô (JD/clipboard), tokenize và khớp từng token với CSDL thuật
/// ngữ qua hàm [lookup] do caller cung cấp. Bảo vệ ràng buộc nghiệp vụ: văn bản
/// dán vào phải có độ dài < 10.000 ký tự.
class DecodeToken {
  const DecodeToken({required this.text, required this.termId});

  /// Nguyên văn một token (từ hoặc khoảng phân cách) từ văn bản gốc.
  final String text;

  /// null nếu token không khớp thuật ngữ nào.
  final String? termId;

  bool get isMatch => termId != null;
}

class DecodeResult {
  const DecodeResult({
    required this.tokens,
    required this.truncated,
    required this.originalLength,
  });

  final List<DecodeToken> tokens;

  /// Văn bản vượt quá giới hạn và đã bị cắt bớt.
  final bool truncated;
  final int originalLength;

  List<String> get matchedTermIds =>
      tokens.map((t) => t.termId).whereType<String>().toList();

  int get matchCount => matchedTermIds.length;
}

class ContextDecoder {
  const ContextDecoder({this.maxChars = 10000});

  /// FR-DEC-01: đầu vào văn bản thô < 10.000 ký tự. Vượt ngưỡng thì cắt bớt
  /// thay vì crash, để ứng dụng không bao giờ nhận payload không kiểm soát.
  final int maxChars;

  /// Token là cả một từ Unicode: cắt theo [A-Za-z] sẽ biến "Cần" thành "C" và
  /// "n", rồi highlight nhầm các acronym một ký tự trong câu tiếng Việt.
  static final _tokenPattern = RegExp(r'[\p{L}\p{N}/]+|[^\p{L}\p{N}/]+', unicode: true);

  DecodeResult decode(String raw, String? Function(String token) lookup) {
    final truncated = raw.length > maxChars;
    final text = truncated ? raw.substring(0, maxChars) : raw;
    final tokens = <DecodeToken>[];
    for (final m in _tokenPattern.allMatches(text)) {
      final token = m.group(0)!;
      tokens.add(DecodeToken(text: token, termId: lookup(token)));
    }
    return DecodeResult(
      tokens: tokens,
      truncated: truncated,
      originalLength: raw.length,
    );
  }
}
