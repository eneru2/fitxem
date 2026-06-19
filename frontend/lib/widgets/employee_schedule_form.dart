import 'package:flutter/material.dart';
import 'package:fitxem/models/schedule_slot.dart';
import 'package:fitxem/models/schedule_template.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/schedule_slot_editor.dart';

/// Shared schedule + vacation fields for employee create/edit forms.
class EmployeeScheduleForm extends StatelessWidget {
  const EmployeeScheduleForm({
    super.key,
    required this.vacationDaysController,
    required this.scheduleType,
    required this.onScheduleTypeChanged,
    required this.templates,
    required this.selectedTemplateId,
    required this.onTemplateChanged,
    required this.weeklyHoursController,
    required this.slots,
    required this.onSlotsChanged,
  });

  final TextEditingController vacationDaysController;
  final String scheduleType;
  final ValueChanged<String> onScheduleTypeChanged;
  final List<ScheduleTemplate> templates;
  final String? selectedTemplateId;
  final ValueChanged<String?> onTemplateChanged;
  final TextEditingController weeklyHoursController;
  final List<ScheduleSlot> slots;
  final ValueChanged<List<ScheduleSlot>> onSlotsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: vacationDaysController,
          decoration: AppTheme.inputDecoration('Días de vacaciones anuales'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),
        Text('Horario', style: AppTheme.sectionTitle(context)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ['none', 'template', 'custom', 'flexible'])
              ChoiceChip(
                label: Text(scheduleTypeLabel(type)),
                selected: scheduleType == type,
                onSelected: (_) => onScheduleTypeChanged(type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (scheduleType == 'template') ...[
          DropdownButtonFormField<String>(
            value: selectedTemplateId,
            decoration: AppTheme.inputDecoration('Plantilla de horario'),
            items: templates
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.name} (${scheduleTypeLabel(t.scheduleType)})'),
                    ))
                .toList(),
            onChanged: onTemplateChanged,
          ),
        ],
        if (scheduleType == 'custom') ...[
          ScheduleSlotEditor(slots: slots, onChanged: onSlotsChanged),
        ],
        if (scheduleType == 'flexible') ...[
          TextField(
            controller: weeklyHoursController,
            decoration: AppTheme.inputDecoration('Horas semanales'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ],
    );
  }
}

Map<String, dynamic> buildEmployeeSchedulePayload({
  required String scheduleType,
  String? templateId,
  required String weeklyHoursText,
  required List<ScheduleSlot> slots,
  required String vacationDaysText,
}) {
  final payload = <String, dynamic>{
    'vacation_days_annual': int.tryParse(vacationDaysText.trim()) ?? 22,
    'schedule_type': scheduleType,
  };
  if (scheduleType == 'template' && templateId != null) {
    payload['schedule_template_id'] = templateId;
  }
  if (scheduleType == 'flexible') {
    final hours = double.tryParse(weeklyHoursText.trim());
    if (hours != null) payload['weekly_hours'] = hours;
  }
  if (scheduleType == 'custom' && slots.isNotEmpty) {
    payload['slots'] = slots.map((s) => s.toJson()).toList();
  }
  return payload;
}
