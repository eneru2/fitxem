import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/schedule_slot.dart';
import 'package:fitxem/models/schedule_template.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/employee_schedule_form.dart';
import 'package:fitxem/widgets/schedule_slot_editor.dart';

class AdminEmployeeFormScreen extends ConsumerStatefulWidget {
  const AdminEmployeeFormScreen({super.key, this.employee});

  final Map<String, dynamic>? employee;

  bool get isEditing => employee != null;

  @override
  ConsumerState<AdminEmployeeFormScreen> createState() =>
      _AdminEmployeeFormScreenState();
}

class _AdminEmployeeFormScreenState
    extends ConsumerState<AdminEmployeeFormScreen> {
  final _nif = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _vacationDays = TextEditingController(text: '22');
  final _weeklyHours = TextEditingController(text: '40');

  List<ScheduleTemplate> _templates = [];
  String _scheduleType = 'none';
  String? _templateId;
  List<ScheduleSlot> _slots = ScheduleSlotEditor.defaultWeekdaySlots();
  bool _loading = true;
  bool _loadingSchedule = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    if (e != null) {
      _vacationDays.text = '${e['vacation_days_annual'] ?? 22}';
      _weeklyHours.text = '${e['weekly_hours'] ?? 40}';
      _scheduleType = e['schedule_type'] as String? ?? 'none';
      _templateId = e['schedule_template_id'] as String?;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await ref.read(apiClientProvider).listScheduleTemplates();
      if (!mounted) return;
      setState(() => _templates = templates);
      if (widget.isEditing && _scheduleType == 'custom') {
        await _loadSchedule();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSchedule() async {
    setState(() => _loadingSchedule = true);
    try {
      final employeeId = widget.employee!['id'] as String;
      final sched =
          await ref.read(apiClientProvider).getEmployeeSchedule(employeeId);
      if (!mounted) return;
      if (sched.slots.isNotEmpty) {
        setState(() => _slots = List.from(sched.slots));
      }
    } catch (_) {
      // Keep defaults if schedule cannot be loaded.
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  @override
  void dispose() {
    _nif.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _vacationDays.dispose();
    _weeklyHours.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_scheduleType == 'custom' && !scheduleSlotsAreValid(_slots)) return;
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final schedulePayload = buildEmployeeSchedulePayload(
        scheduleType: _scheduleType,
        templateId: _templateId,
        weeklyHoursText: _weeklyHours.text,
        slots: _slots,
        vacationDaysText: _vacationDays.text,
      );
      if (widget.isEditing) {
        await api.assignEmployeeSchedule(
          widget.employee!['id'] as String,
          schedulePayload,
        );
      } else {
        await api.createEmployee({
          'nif': _nif.text.trim(),
          'full_name': _name.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
          ...schedulePayload,
        });
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
    final l10n = AppLocalizations.of(context)!;

    if (_loading) return const AppLoadingPage();

    final name = widget.employee?['full_name'] as String? ?? '';
    final title = widget.isEditing ? 'Editar $name' : 'Añadir empleado';
    final subtitle = widget.isEditing
        ? 'Actualiza el horario y los días de vacaciones.'
        : 'Introduce los datos del nuevo empleado.';

    return AppPage(
      children: [
        const AppBackButton(),
        const SizedBox(height: 24),
        AppPageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 28),
        AppSoftCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isEditing) ...[
                  TextField(
                    controller: _nif,
                    decoration: AppTheme.inputDecoration('NIF'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _name,
                    decoration: AppTheme.inputDecoration(l10n.ownerName),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    decoration: AppTheme.inputDecoration(l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    decoration: AppTheme.inputDecoration(l10n.password),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                ],
                if (_loadingSchedule && _scheduleType == 'custom')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  EmployeeScheduleForm(
                    vacationDaysController: _vacationDays,
                    scheduleType: _scheduleType,
                    onScheduleTypeChanged: (v) =>
                        setState(() => _scheduleType = v),
                    templates: _templates,
                    selectedTemplateId: _templateId,
                    onTemplateChanged: (v) => setState(() => _templateId = v),
                    weeklyHoursController: _weeklyHours,
                    slots: _slots,
                    onSlotsChanged: (v) => setState(() => _slots = v),
                  ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: widget.isEditing ? 'Guardar cambios' : 'Crear empleado',
                  enabled: !_submitting &&
                      (_scheduleType != 'custom' ||
                          scheduleSlotsAreValid(_slots)),
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
