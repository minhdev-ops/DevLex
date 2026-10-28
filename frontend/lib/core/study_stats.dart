import '../data/models/term.dart';

/// FR-QUIZ-03: tiến trình ghi nhớ và điểm động lực, tính thuần từ bảng study_state
/// để màn hình chỉ việc vẽ và test được không cần SQLite.
class StudyStats {
  const StudyStats({
    required this.fresh,
    required this.day1,
    required this.day3,
    required this.day7,
    required this.dueNow,
    required this.bestStreak,
  });

  factory StudyStats.from(Iterable<StudyState> states, {DateTime? now}) {
    var fresh = 0, day1 = 0, day3 = 0, day7 = 0, due = 0, best = 0;
    final reference = (now ?? DateTime.now()).toUtc();

    for (final s in states) {
      switch (s.intervalDays) {
        case 1:
          day1++;
        case 3:
          day3++;
        case >= 7:
          day7++;
        default:
          fresh++;
      }
      if (s.streak > best) best = s.streak;
      final dueAt = s.dueDate;
      if (dueAt != null && DateTime.parse(dueAt).isBefore(reference)) due++;
    }

    return StudyStats(
      fresh: fresh,
      day1: day1,
      day3: day3,
      day7: day7,
      dueNow: due,
      bestStreak: best,
    );
  }

  static const empty = StudyStats(
    fresh: 0,
    day1: 0,
    day3: 0,
    day7: 0,
    dueNow: 0,
    bestStreak: 0,
  );

  /// Chưa ôn lần nào (mới đánh dấu "đã học").
  final int fresh;

  final int day1;
  final int day3;
  final int day7;

  /// Thẻ đã tới hạn (kể cả quá hạn) cần ôn ngay hôm nay.
  final int dueNow;

  final int bestStreak;

  int get reviewed => day1 + day3 + day7;

  int get tracked => fresh + reviewed;

  /// Tỷ lệ thẻ đã lên chu kỳ dài nhất trong số thẻ đã ôn ít nhất một lần.
  double get longTermShare => reviewed == 0 ? 0 : day7 / reviewed;

  /// Điểm động lực: thẻ càng đứng chu kỳ dài càng đáng giá, streak cộng thưởng.
  int get points => day1 * 2 + day3 * 5 + day7 * 10 + bestStreak * 3;

  /// Bốn bậc thang SRS (mục 2.4) theo thứ tự tăng dần độ vững kiến thức.
  List<(String label, int count)> get ladder => [
        ('Mới đánh dấu', fresh),
        ('1 ngày', day1),
        ('3 ngày', day3),
        ('7 ngày', day7),
      ];
}
