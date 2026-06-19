import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:fitxem/models/absence_request.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _prefsKeyReminders = 'clock_reminders_enabled';

/// Local clock-in reminders are only supported on Android and iOS.
bool get notificationsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final reminderServiceProvider = Provider((ref) {
  return ReminderService(ref.watch(apiClientProvider));
});

class ReminderService {
  ReminderService(this._api);

  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _androidChannel = AndroidNotificationChannel(
    'clock_reminders',
    'Recordatorios de fichaje',
    description: 'Avisos si no has fichado la entrada',
    importance: Importance.high,
  );

  Future<bool> isEnabled() async {
    if (!notificationsSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyReminders) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!notificationsSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyReminders, enabled);
    if (!enabled) {
      await cancelAll();
    } else {
      await syncReminders();
    }
  }

  Future<void> initialize() async {
    if (!notificationsSupported || _initialized) return;

    tz_data.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> syncReminders() async {
    if (!notificationsSupported || !await isEnabled()) return;
    await initialize();

    try {
      final schedule = await _api.getMySchedule();
      if (!schedule.hasRigidSchedule || schedule.slots.isEmpty) {
        await cancelAll();
        return;
      }

      final today = DateTime.now();
      final rangeEnd = today.add(const Duration(days: 7));
      final absences = await _api.listAbsencesInRange(
        from: _dateKey(today),
        to: _dateKey(rangeEnd),
      );
      final todayStatus = await _api.todayStatus();
      final hasClockedInToday = _hasClockInToday(todayStatus);

      await cancelAll();

      final location = tz.getLocation(schedule.timezone);
      final now = tz.TZDateTime.now(location);

      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        final date = DateTime(today.year, today.month, today.day + dayOffset);
        if (_isOnApprovedAbsence(date, absences)) continue;

        final dartWeekday = date.weekday;
        final scheduleDay = dartWeekday - 1;

        for (final slot in schedule.slots) {
          if (slot.dayOfWeek != scheduleDay) continue;

          final startParts = slot.startTime.split(':');
          final startHour = int.parse(startParts[0]);
          final startMinute = int.parse(startParts[1]);

          final scheduledStart = tz.TZDateTime(
            location,
            date.year,
            date.month,
            date.day,
            startHour,
            startMinute,
          );

          if (dayOffset == 0 && hasClockedInToday) continue;

          for (final minutes in [5, 10, 15]) {
            final fireAt = scheduledStart.add(Duration(minutes: minutes));
            if (!fireAt.isAfter(now)) continue;

            final id = _notificationId(date, slot.dayOfWeek, minutes);
            await _notifications.zonedSchedule(
              id,
              'Recordatorio de fichaje',
              'Aún no has fichado la entrada (+$minutes min)',
              fireAt,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _androidChannel.id,
                  _androidChannel.name,
                  channelDescription: _androidChannel.description,
                  importance: Importance.high,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(),
              ),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
        }
      }
    } catch (_) {
      // Best-effort; reminders resync on next app open.
    }
  }

  Future<void> cancelTodayReminders() async {
    if (!notificationsSupported) return;
    final today = DateTime.now();
    for (var day = 0; day < 7; day++) {
      for (var slotDay = 0; slotDay < 7; slotDay++) {
        for (final minutes in [5, 10, 15]) {
          final date = DateTime(today.year, today.month, today.day + day);
          await _notifications.cancel(_notificationId(date, slotDay, minutes));
        }
      }
    }
  }

  Future<void> cancelAll() async {
    if (!notificationsSupported) return;
    await _notifications.cancelAll();
  }

  int _notificationId(DateTime date, int slotDay, int minutes) {
    return date.year * 100000 +
        date.month * 10000 +
        date.day * 100 +
        slotDay * 10 +
        (minutes ~/ 5);
  }

  String _dateKey(DateTime d) =>
      DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

  bool _isOnApprovedAbsence(DateTime date, List<AbsenceRequest> absences) {
    final day = DateTime(date.year, date.month, date.day);
    for (final a in absences) {
      if (a.coversDay(day)) return true;
    }
    return false;
  }

  bool _hasClockInToday(Map<String, dynamic> todayStatus) {
    final events = todayStatus['events'] as List<dynamic>? ?? [];
    for (final raw in events) {
      final e = Map<String, dynamic>.from(raw as Map);
      final type = e['event_type'] as String?;
      if (type == 'in' || type == 'break_end') return true;
    }
    return false;
  }
}
