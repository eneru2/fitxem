import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/absence_request.dart';
import 'package:fitxem/models/clock_event.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/utils/time_grouping.dart';
import 'package:fitxem/widgets/marcaje_row.dart';
import 'package:fitxem/widgets/request_labels.dart';

class HistoryDayCard extends StatelessWidget {
  const HistoryDayCard({
    super.key,
    required this.day,
    required this.events,
    this.absence,
    required this.expanded,
    required this.onToggle,
    required this.onEventTap,
    required this.onLocationTap,
    this.onForgotClock,
  });

  final DateTime day;
  final List<ClockEvent> events;
  final AbsenceRequest? absence;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(ClockEvent event) onEventTap;
  final void Function(ClockEvent event) onLocationTap;
  final VoidCallback? onForgotClock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekdayFmt = DateFormat('EEEE', 'es');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day == today;
    final isFutureDay = day.isAfter(today);
    final subtitle = absence != null
        ? absenceTypeLabel(l10n, absence!.absenceType)
        : (primaryWorkCenterForDay(events) ??
            (isFutureDay ? l10n.dayNotYetOccurred : l10n.noRecordsForDay));
    final totalSeconds = workedSecondsForDay(events);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.softCard(radius: AppTheme.radiusMd),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.textPrimary : AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      '${day.day}',
                      style: AppTheme.rowTitle(context).copyWith(
                        color: isToday ? Colors.white : AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weekdayFmt.format(day).toLowerCase(),
                          style: AppTheme.rowTitle(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTheme.rowMeta(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            if (absence != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.sun_max,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${l10n.absenceDayLabel}: ${absenceTypeLabel(l10n, absence!.absenceType)}',
                        style: AppTheme.rowTitle(context),
                      ),
                    ),
                  ],
                ),
              ),
            if (events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.marcajes,
                  style: AppTheme.sectionTitle(context),
                ),
              ),
            ),
            for (var i = 0; i < events.length; i++)
              MarcajeRow(
                event: events[i],
                showDivider: i > 0,
                onTap: () => onEventTap(events[i]),
                onLocationTap: () => onLocationTap(events[i]),
              ),
            ],
            if (events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.noIncidentMinutes,
                      style: AppTheme.rowMeta(context),
                    ),
                  ),
                  Text(
                    formatDurationHm(totalSeconds),
                    style: AppTheme.rowTitle(context),
                  ),
                ],
              ),
            ),
            if (isFutureDay && events.isEmpty && absence == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  l10n.dayNotYetOccurred,
                  style: AppTheme.rowMeta(context),
                  textAlign: TextAlign.center,
                ),
              ),
            if (onForgotClock != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onForgotClock,
                    style: AppTheme.outlinedButtonStyle().copyWith(
                      minimumSize:
                          const WidgetStatePropertyAll(Size.fromHeight(44)),
                    ),
                    child: Text(l10n.forgotClockThisDay),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
