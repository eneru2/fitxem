import 'package:flutter/material.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/theme/app_theme.dart';

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, bg, fg) = switch (status) {
      'approved' => (l10n.statusApproved, AppTheme.greenMuted, AppTheme.greenText),
      'rejected' => (
          l10n.statusRejected,
          const Color(0xFFFFF0F0),
          const Color(0xFFC62828),
        ),
      _ => (l10n.statusPending, const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

String incidentTypeLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'forgot_clock' => l10n.incidentForgotClock,
    'wrong_time' => l10n.incidentWrongTime,
    _ => l10n.incidentOther,
  };
}

String eventTypeLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'in' => l10n.clockIn,
    'out' => l10n.clockOut,
    'break_start' => l10n.breakStart,
    'break_end' => l10n.breakEnd,
    _ => type,
  };
}

String absenceTypeLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'vacation' => l10n.absenceVacation,
    'sick' => l10n.absenceSick,
    'personal' => l10n.absencePersonal,
    'unpaid' => l10n.absenceUnpaid,
    _ => type,
  };
}
