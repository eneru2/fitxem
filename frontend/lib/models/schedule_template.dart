import 'package:fitxem/models/schedule_slot.dart';

class ScheduleTemplate {
  const ScheduleTemplate({
    required this.id,
    required this.name,
    required this.scheduleType,
    this.weeklyHours,
    this.slots = const [],
  });

  final String id;
  final String name;
  final String scheduleType;
  final double? weeklyHours;
  final List<ScheduleSlot> slots;

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    return ScheduleTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      scheduleType: json['schedule_type'] as String,
      weeklyHours: (json['weekly_hours'] as num?)?.toDouble(),
      slots: rawSlots
          .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'schedule_type': scheduleType,
        if (weeklyHours != null) 'weekly_hours': weeklyHours,
        'slots': slots.map((s) => s.toJson()).toList(),
      };
}
