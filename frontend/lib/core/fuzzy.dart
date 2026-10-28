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

double similarity(String needle, String candidate) {
  if (needle.isEmpty || candidate.isEmpty) return 0;
  if (candidate == needle) return 1;
  if (candidate.startsWith(needle) || candidate.contains(needle)) {
    return 0.9 + 0.1 * (needle.length / candidate.length);
  }
  final dist = levenshtein(needle, candidate);
  final maxLen = needle.length > candidate.length ? needle.length : candidate.length;
  final score = 1 - dist / maxLen;
  return score < 0 ? 0 : score;
}
