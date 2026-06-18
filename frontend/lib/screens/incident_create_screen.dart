import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/request_labels.dart';

class IncidentCreateScreen extends ConsumerStatefulWidget {
  const IncidentCreateScreen({
    super.key,
    required this.mode,
    this.initialEventType,
    this.initialProposedAt,
    this.relatedEventId,
  });

  final String mode;
  final String? initialEventType;
  final DateTime? initialProposedAt;
  final String? relatedEventId;

  bool get isWrongTime => mode == 'wrong_time';

  @override
  ConsumerState<IncidentCreateScreen> createState() =>
      _IncidentCreateScreenState();
}

class _IncidentCreateScreenState extends ConsumerState<IncidentCreateScreen> {
  static const _eventTypes = ['in', 'out', 'break_start', 'break_end'];

  final _reason = TextEditingController();
  String? _employeeId;
  late String _eventType;
  late DateTime _day;
  late TimeOfDay _time;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProposedAt ?? DateTime.now();
    _day = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay.fromDateTime(initial);
    if (widget.initialEventType != null &&
        _eventTypes.contains(widget.initialEventType)) {
      _eventType = widget.initialEventType!;
    } else {
      _eventType = 'in';
    }
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime get _proposedAt => DateTime(
        _day.year,
        _day.month,
        _day.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ref.read(apiClientProvider).todayStatus();
      if (!mounted) return;
      setState(() => _employeeId = data['employee_id'] as String?);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (!mounted || picked == null) return;
    setState(() => _day = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (!mounted || picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final employeeId = _employeeId;
    final reason = _reason.text.trim();

    if (employeeId == null || employeeId.isEmpty) {
      setState(() => _error = l10n.error);
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = l10n.reasonHint);
      return;
    }
    if (widget.isWrongTime && widget.relatedEventId == null) {
      setState(() => _error = l10n.errorInvalidData);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).createCorrection(
            employeeId: employeeId,
            eventType: _eventType,
            proposedAt: _proposedAt,
            reason: reason,
            incidentType: widget.mode,
            relatedEventId:
                widget.isWrongTime ? widget.relatedEventId : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.correctionSubmitted)),
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
    final dayFmt = DateFormat('EEEE, d MMMM', 'es');
    final shortDayFmt = DateFormat('d MMM', 'es');
    final timeFmt = DateFormat('HH:mm', 'es');
    final originalTime = widget.initialProposedAt;

    if (_loading) return const AppLoadingPage();

    final title =
        widget.isWrongTime ? l10n.fixTime : l10n.incidentForgotClock;
    final subtitle = widget.isWrongTime
        ? l10n.fixTimeSubtitle
        : l10n.incidentForgotClockDesc;

    return AppPage(
      children: [
        _BackButton(onTap: () => context.pop()),
        const SizedBox(height: 24),
        AppPageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 28),
        AppSoftCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isWrongTime && originalTime != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      '${eventTypeLabel(l10n, _eventType)} · ${shortDayFmt.format(originalTime)} · ${l10n.originalTime} ${timeFmt.format(originalTime)}',
                      style: AppTheme.rowTitle(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (!widget.isWrongTime) ...[
                  Text(l10n.eventType, style: AppTheme.sectionTitle(context)),
                  const SizedBox(height: 10),
                  _EventTypePicker(
                    value: _eventType,
                    onChanged: (v) => setState(() => _eventType = v),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.correctionDay, style: AppTheme.sectionTitle(context)),
                  const SizedBox(height: 10),
                  _PickerField(
                    label: dayFmt.format(_day),
                    onTap: _pickDay,
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  widget.isWrongTime
                      ? l10n.proposedTimeLabel
                      : l10n.correctionTime,
                  style: AppTheme.sectionTitle(context),
                ),
                const SizedBox(height: 10),
                _PickerField(
                  label: timeFmt.format(
                    DateTime(2000, 1, 1, _time.hour, _time.minute),
                  ),
                  onTap: _pickTime,
                ),
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
                  label: _submitting ? l10n.loading : l10n.submitCorrection,
                  enabled: !_submitting,
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

class _EventTypePicker extends StatelessWidget {
  const _EventTypePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      'in': l10n.clockIn,
      'out': l10n.clockOut,
      'break_start': l10n.breakStart,
      'break_end': l10n.breakEnd,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries.map((e) {
        final selected = value == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (_) => onChanged(e.key),
        );
      }).toList(),
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
