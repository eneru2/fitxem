import 'package:fitxem/models/schedule_slot.dart';

class EmployeeSchedule {
  const EmployeeSchedule({
    required this.scheduleType,
    this.scheduleTemplateId,
    this.weeklyHours,
    required this.timezone,
    this.slots = const [],
  });

  final String scheduleType;
  final String? scheduleTemplateId;
  final double? weeklyHours;
  final String timezone;
  final List<ScheduleSlot> slots;

  bool get hasRigidSchedule =>
      scheduleType == 'template' || scheduleType == 'custom';

  factory EmployeeSchedule.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    return EmployeeSchedule(
      scheduleType: json['schedule_type'] as String? ?? 'none',
      scheduleTemplateId: json['schedule_template_id'] as String?,
      weeklyHours: (json['weekly_hours'] as num?)?.toDouble(),
      timezone: json['timezone'] as String? ?? 'Europe/Madrid',
      slots: rawSlots
          .map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
