import 'package:fitxem/models/clock_event.dart';

/// Monday-based start of the week containing [date] (local time).
DateTime weekStart(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final weekday = local.weekday;
  return local.subtract(Duration(days: weekday - DateTime.monday));
}

/// End of week (Sunday 23:59:59.999) containing [date].
DateTime weekEnd(DateTime date) {
  final start = weekStart(date);
  return DateTime(start.year, start.month, start.day + 6, 23, 59, 59, 999);
}

List<DateTime> daysInWeek(DateTime anchor) {
  final start = weekStart(anchor);
  return List.generate(
    7,
    (i) => DateTime(start.year, start.month, start.day + i),
  );
}

Map<DateTime, List<ClockEvent>> groupEventsByDay(List<ClockEvent> events) {
  final groups = <DateTime, List<ClockEvent>>{};
  for (final event in events) {
    final day = DateTime(
      event.recordedAt.year,
      event.recordedAt.month,
      event.recordedAt.day,
    );
    groups.putIfAbsent(day, () => []).add(event);
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }
  return groups;
}

int workedSecondsForDay(List<ClockEvent> events, {DateTime? asOf}) {
  if (events.isEmpty) return 0;

  final sorted = [...events]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  final firstDay = sorted.first.recordedAt;
  final dayStart = DateTime(firstDay.year, firstDay.month, firstDay.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final now = asOf ?? DateTime.now();
  final effectiveAsOf = now.isBefore(dayEnd) ? now : dayEnd;

  DateTime? workStart;
  var total = Duration.zero;

  for (final ev in sorted) {
    final at = ev.recordedAt;
    switch (ev.eventType) {
      case 'in':
      case 'break_end':
        workStart = at;
      case 'out':
      case 'break_start':
        if (workStart != null) {
          total += at.difference(workStart);
          workStart = null;
        }
    }
  }
  if (workStart != null) {
    total += effectiveAsOf.difference(workStart);
  }
  return total.inSeconds;
}

/// Formats as `7:45` (hours:minutes) for history totals.
String formatDurationHm(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  return '$hours:${minutes.toString().padLeft(2, '0')}';
}

/// Formats as `8h 30m` for compact labels.
String formatDurationCompact(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return '0m';
}

String? primaryWorkCenterForDay(List<ClockEvent> events) {
  for (final ev in events) {
    if (ev.workCenter != null && ev.workCenter!.isNotEmpty) {
      return ev.workCenter;
    }
  }
  return null;
}
