import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';

class HistoryQuickLinks extends StatelessWidget {
  const HistoryQuickLinks({
    super.key,
    required this.incidentsLabel,
    required this.onIncidentsTap,
    required this.absencesLabel,
    required this.onAbsencesTap,
  });

  final String incidentsLabel;
  final VoidCallback onIncidentsTap;
  final String absencesLabel;
  final VoidCallback onAbsencesTap;

  @override
  Widget build(BuildContext context) {
    return AppSoftCard(
      child: Column(
        children: [
          HistoryListRow(
            label: incidentsLabel,
            icon: CupertinoIcons.doc_text,
            onTap: onIncidentsTap,
          ),
          const Divider(height: 1, indent: 48, color: AppTheme.border),
          HistoryListRow(
            label: absencesLabel,
            icon: CupertinoIcons.sun_max,
            onTap: onAbsencesTap,
          ),
        ],
      ),
    );
  }
}

class HistoryListRow extends StatelessWidget {
  const HistoryListRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: AppTheme.rowTitle(context)),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
