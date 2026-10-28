import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/study_stats.dart';
import 'package:it_glossary/data/models/term.dart';

StudyState state({
  String id = 't',
  int intervalDays = 0,
  String? dueDate,
  int streak = 0,
}) =>
    StudyState(
      termId: id,
      learned: intervalDays > 0,
      intervalDays: intervalDays,
      dueDate: dueDate,
      streak: streak,
    );

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);

  test('rỗng thì không có gì để vẽ', () {
    const stats = StudyStats.empty;
    expect(stats.tracked, 0);
    expect(stats.points, 0);
    expect(stats.longTermShare, 0);
    expect(stats.ladder.map((r) => r.$2), everyElement(0));
  });

  test('gom thẻ theo đúng bậc thang SRS 1/3/7 ngày', () {
    final stats = StudyStats.from([
      state(id: 'a'),
      state(id: 'b', intervalDays: 1),
      state(id: 'c', intervalDays: 3),
      state(id: 'd', intervalDays: 7),
      state(id: 'e', intervalDays: 21),
    ], now: now);

    expect(stats.fresh, 1);
    expect(stats.day1, 1);
    expect(stats.day3, 1);
    expect(stats.day7, 2);
    expect(stats.reviewed, 4);
    expect(stats.tracked, 5);
    expect(stats.ladder.map((r) => r.$2).toList(), [1, 1, 1, 2]);
  });

  test('điểm thưởng tính theo chu kỳ dài và streak tốt nhất', () {
    final stats = StudyStats.from([
      state(intervalDays: 1),
      state(intervalDays: 1),
      state(intervalDays: 3),
      state(intervalDays: 7),
      state(intervalDays: 3, streak: 2),
      state(intervalDays: 7, streak: 5),
    ], now: now);

    // 2 thẻ ×2 + 2 thẻ ×5 + 2 thẻ ×10 + streak 5 ×3
    expect(stats.bestStreak, 5);
    expect(stats.points, 2 * 2 + 2 * 5 + 2 * 10 + 5 * 3);
  });

  test('chỉ đếm thẻ đến hạn hoặc quá hạn so với mốc thời gian', () {
    final stats = StudyStats.from([
      state(id: 'overdue', intervalDays: 3, dueDate: '2026-10-20T00:00:00Z'),
      state(id: 'due', intervalDays: 1, dueDate: '2026-10-28T11:59:59Z'),
      state(id: 'later', intervalDays: 7, dueDate: '2026-11-04T00:00:00Z'),
      state(id: 'no-due', intervalDays: 1),
    ], now: now);

    expect(stats.dueNow, 2);
  });

  test('tỷ lệ dài hạn chỉ tính trên thẻ đã ôn ít nhất một lần', () {
    final stats = StudyStats.from([
      state(id: 'fresh1'),
      state(id: 'fresh2'),
      state(id: 'r1', intervalDays: 1),
      state(id: 'r7', intervalDays: 7),
    ], now: now);

    expect(stats.longTermShare, 0.5);
  });
}
