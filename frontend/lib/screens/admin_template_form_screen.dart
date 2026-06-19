import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/models/schedule_slot.dart';
import 'package:fitxem/models/schedule_template.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/schedule_slot_editor.dart';

class AdminTemplateFormScreen extends ConsumerStatefulWidget {
  const AdminTemplateFormScreen({super.key, this.template});

  final ScheduleTemplate? template;

  bool get isEditing => template != null;

  @override
  ConsumerState<AdminTemplateFormScreen> createState() =>
      _AdminTemplateFormScreenState();
}

class _AdminTemplateFormScreenState
    extends ConsumerState<AdminTemplateFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _weeklyHours;
  late String _type;
  List<ScheduleSlot> _slots = ScheduleSlotEditor.defaultWeekdaySlots();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(text: t?.name ?? '');
    _weeklyHours = TextEditingController(text: '${t?.weeklyHours ?? 40}');
    _type = t?.scheduleType ?? 'fixed';
    if (t != null && t.slots.isNotEmpty) {
      _slots = List.from(t.slots);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _weeklyHours.dispose();
    super.dispose();
  }

  bool get _nameIsValid => _name.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_nameIsValid) return;
    if (_type == 'fixed' && !scheduleSlotsAreValid(_slots)) return;
    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'schedule_type': _type,
      };
      if (_type == 'flexible') {
        data['weekly_hours'] = double.tryParse(_weeklyHours.text.trim()) ?? 40;
      } else {
        data['slots'] = _slots.map((s) => s.toJson()).toList();
      }
      final api = ref.read(apiClientProvider);
      if (widget.isEditing) {
        await api.updateScheduleTemplate(widget.template!.id, data);
      } else {
        await api.createScheduleTemplate(data);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isEditing ? 'Editar plantilla' : 'Nueva plantilla';

    return AppPage(
      children: [
        const AppBackButton(),
        const SizedBox(height: 24),
        AppPageHeader(
          title: title,
          subtitle: 'Define un horario reutilizable para asignar a empleados.',
        ),
        const SizedBox(height: 28),
        AppSoftCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: AppTheme.inputDecoration('Nombre'),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Fijo'),
                      selected: _type == 'fixed',
                      onSelected: (_) => setState(() => _type = 'fixed'),
                    ),
                    ChoiceChip(
                      label: const Text('Flexible'),
                      selected: _type == 'flexible',
                      onSelected: (_) => setState(() => _type = 'flexible'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_type == 'fixed')
                  ScheduleSlotEditor(
                    slots: _slots,
                    onChanged: (v) => setState(() => _slots = v),
                  )
                else
                  TextField(
                    controller: _weeklyHours,
                    decoration: AppTheme.inputDecoration('Horas semanales'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Guardar',
                  enabled: !_submitting &&
                      _nameIsValid &&
                      (_type != 'fixed' || scheduleSlotsAreValid(_slots)),
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
