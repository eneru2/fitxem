class ScheduleSlot {
  const ScheduleSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final int dayOfWeek;
  final String startTime;
  final String endTime;

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    return ScheduleSlot(
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      };

  ScheduleSlot copyWith({
    int? dayOfWeek,
    String? startTime,
    String? endTime,
  }) {
    return ScheduleSlot(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

int scheduleMinutes(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Returns a user-facing error for a single day's slots, or null if valid.
String? validateDaySlots(List<ScheduleSlot> daySlots) {
  if (daySlots.isEmpty) return null;

  for (final slot in daySlots) {
    if (scheduleMinutes(slot.endTime) <= scheduleMinutes(slot.startTime)) {
      return 'La hora de fin debe ser posterior al inicio';
    }
  }

  final sorted = List<ScheduleSlot>.from(daySlots)
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  for (var i = 0; i < sorted.length - 1; i++) {
    if (scheduleMinutes(sorted[i].endTime) >
        scheduleMinutes(sorted[i + 1].startTime)) {
      return 'Los tramos se solapan';
    }
  }

  return null;
}

bool scheduleSlotsAreValid(List<ScheduleSlot> slots) {
  for (var day = 0; day < 7; day++) {
    final daySlots = slots.where((s) => s.dayOfWeek == day).toList();
    if (validateDaySlots(daySlots) != null) return false;
  }
  return true;
}

const scheduleDayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

const scheduleDayFullLabels = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String scheduleTypeLabel(String type) {
  switch (type) {
    case 'template':
      return 'Plantilla';
    case 'custom':
      return 'Personalizado';
    case 'flexible':
      return 'Flexible';
    case 'fixed':
      return 'Fijo';
    case 'none':
      return 'Sin horario';
    default:
      return type;
  }
}
