import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/local/glossary_database.dart';

/// Nhắc học mỗi ngày bằng thông báo hệ thống.
///
/// Cài đặt lưu trong sync_meta nên không cần tài khoản; lịch nhắc được đặt lại
/// sau mỗi lần mở app để không mất khi người dùng đổi múi giờ.
class Reminders {
  Reminders._();

  static final Reminders instance = Reminders._();

  static const _onKey = 'reminder_on';
  static const _timeKey = 'reminder_time';
  static const _notificationId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  final ValueNotifier<TimeOfDayLike> time = ValueNotifier<TimeOfDayLike>(
    const TimeOfDayLike(20, 0),
  );

  bool _ready = false;

  Future<void> load() async {
    if (_ready) return;
    _ready = true;
    try {
      final on = await GlossaryDatabase.instance.getMeta(_onKey);
      final raw = await GlossaryDatabase.instance.getMeta(_timeKey);
      enabled.value = on == 'true';
      final parsed = _parse(raw);
      if (parsed != null) time.value = parsed;
    } catch (_) {
      // Chưa mở được DB: giữ mặc định, không chặn app.
    }
  }

  Future<void> init() async {
    await load();
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {
      // Không lấy được múi giờ: dùng UTC, lịch vẫn đặt được.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    if (enabled.value) {
      // Đặt lại lịch sau khi mở app: lịch cũ có thể đã trôi theo múi giờ khác.
      await scheduleDaily(hour: time.value.hour, minute: time.value.minute);
    }
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      await GlossaryDatabase.instance.setMeta(_onKey, value ? 'true' : 'false');
    } catch (_) {
      // Không lưu được cũng vẫn giữ trạng thái trong phiên.
    }
    if (value) {
      await requestPermission();
      await scheduleDaily(hour: time.value.hour, minute: time.value.minute);
    } else {
      await cancel();
    }
  }

  Future<void> setTime(int hour, int minute) async {
    time.value = TimeOfDayLike(hour, minute);
    try {
      await GlossaryDatabase.instance.setMeta(
        _timeKey,
        _format(hour, minute),
      );
    } catch (_) {
      // bỏ qua
    }
    if (enabled.value) await scheduleDaily(hour: hour, minute: minute);
  }

  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await _plugin.cancel(id: _notificationId);
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Đến giờ ôn thuật ngữ',
      body: 'Vài thẻ flashcard hôm nay giúp bạn nhớ lâu hơn — mở DevLex nhé.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_reminder',
          'Nhắc học',
          channelDescription: 'Thông báo nhắc ôn tập mỗi ngày',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel() => _plugin.cancel(id: _notificationId);

  static TimeOfDayLike? _parse(String? raw) {
    if (raw == null || !raw.contains(':')) return null;
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDayLike(h, m);
  }

  static String _format(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Giờ nhắc tối giản, không phụ thuộc Material để dùng được cả trong test.
class TimeOfDayLike {
  const TimeOfDayLike(this.hour, this.minute);

  final int hour;
  final int minute;

  String get label => Reminders._format(hour, minute);

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayLike && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
