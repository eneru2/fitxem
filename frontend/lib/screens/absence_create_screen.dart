import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/vacation_balance.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';

class AbsenceCreateScreen extends ConsumerStatefulWidget {
  const AbsenceCreateScreen({super.key});

  @override
  ConsumerState<AbsenceCreateScreen> createState() =>
      _AbsenceCreateScreenState();
}

class _AbsenceCreateScreenState extends ConsumerState<AbsenceCreateScreen> {
  final _reason = TextEditingController();
  String? _employeeId;
  String _absenceType = 'vacation';
  late DateTime _start;
  late DateTime _end;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  VacationBalance? _vacationBalance;

  int get _requestedVacationDays =>
      countVacationDays(_start, _end);

  bool get _vacationOverBalance =>
      _absenceType == 'vacation' &&
      _vacationBalance != null &&
      _requestedVacationDays > _vacationBalance!.remaining;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _start = DateTime(today.year, today.month, today.day);
    _end = _start;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.todayStatus();
      final balance = await api.getVacationBalance();
      if (!mounted) return;
      setState(() {
        _employeeId = data['employee_id'] as String?;
        _vacationBalance = balance;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _start = DateTime(picked.year, picked.month, picked.day);
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (!mounted || picked == null) return;
    setState(() => _end = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final employeeId = _employeeId;
    final reason = _reason.text.trim();
    if (employeeId == null || reason.isEmpty) {
      setState(() => _error = l10n.errorInvalidData);
      return;
    }
    if (_vacationOverBalance) {
      setState(() => _error = 'No tienes suficientes días de vacaciones');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).createAbsence(
            employeeId: employeeId,
            absenceType: _absenceType,
            startDate: _start,
            endDate: _end,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.absenceSubmitted)),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('EEEE, d MMMM yyyy', 'es');

    if (_loading) return const AppLoadingPage();

    final types = {
      'vacation': l10n.absenceVacation,
      'sick': l10n.absenceSick,
      'personal': l10n.absencePersonal,
      'unpaid': l10n.absenceUnpaid,
    };

    return AppPage(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              CupertinoIcons.back,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppPageHeader(
          title: l10n.requestAbsence,
          subtitle: 'Elige el tipo, las fechas y el motivo.',
        ),
        const SizedBox(height: 28),
        AppSoftCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.absenceType, style: AppTheme.sectionTitle(context)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.entries.map((e) {
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: _absenceType == e.key,
                      onSelected: (_) => setState(() => _absenceType = e.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(l10n.absenceStart, style: AppTheme.sectionTitle(context)),
                const SizedBox(height: 10),
                _PickerField(
                  label: dateFmt.format(_start),
                  onTap: _pickStart,
                ),
                const SizedBox(height: 20),
                Text(l10n.absenceEnd, style: AppTheme.sectionTitle(context)),
                const SizedBox(height: 10),
                _PickerField(
                  label: dateFmt.format(_end),
                  onTap: _pickEnd,
                ),
                if (_absenceType == 'vacation' && _vacationBalance != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo de vacaciones (${_vacationBalance!.year})',
                          style: AppTheme.sectionTitle(context),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_vacationBalance!.remaining} días disponibles de ${_vacationBalance!.annual} '
                          '(${_vacationBalance!.used} usados)',
                          style: AppTheme.rowMeta(context),
                        ),
                        if (_requestedVacationDays > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Solicitas $_requestedVacationDays días laborables',
                            style: TextStyle(
                              fontSize: 13,
                              color: _vacationOverBalance
                                  ? const Color(0xFFC62828)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _reason,
                  decoration: AppTheme.inputDecoration(l10n.reason).copyWith(
                    hintText: l10n.reasonHint,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: _submitting ? l10n.loading : l10n.submitAbsence,
                  enabled: !_submitting && !_vacationOverBalance,
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

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InputDecorator(
        decoration: AppTheme.inputDecoration(''),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
