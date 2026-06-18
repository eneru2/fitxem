import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/absence_request.dart';
import 'package:fitxem/models/clock_event.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/utils/time_grouping.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/history_action_block.dart';
import 'package:fitxem/widgets/history_day_card.dart';
import 'package:fitxem/widgets/location_map_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    super.key,
    this.initialWeekAnchor,
    this.initialExpandedDay,
  });

  final DateTime? initialWeekAnchor;
  final DateTime? initialExpandedDay;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _weekAnchor;
  DateTime? _expandedDay;
  List<ClockEvent> _events = [];
  List<AbsenceRequest> _absences = [];
  bool _loading = true;
  String? _error;

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime? _defaultExpandedDay() {
    if (widget.initialExpandedDay != null) {
      return _dayOnly(widget.initialExpandedDay!);
    }
    final today = _dayOnly(DateTime.now());
    return daysInWeek(_weekAnchor).contains(today) ? today : null;
  }

  @override
  void initState() {
    super.initState();
    _weekAnchor = widget.initialWeekAnchor ?? DateTime.now();
    _expandedDay = _defaultExpandedDay();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final start = weekStart(_weekAnchor);
      final end = weekEnd(_weekAnchor);
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.myRecords(
          from: start.toUtc().toIso8601String(),
          to: end.toUtc().toIso8601String(),
        ),
        api.listAbsencesInRange(
          from: start.toUtc().toIso8601String(),
          to: end.toUtc().toIso8601String(),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<ClockEvent>;
        _absences = results[1] as List<AbsenceRequest>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftWeek(int delta) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: 7 * delta));
      final today = _dayOnly(DateTime.now());
      _expandedDay =
          daysInWeek(_weekAnchor).contains(today) ? today : null;
      _loading = true;
    });
    _load();
  }

  Future<void> _openCalendar() async {
    final selected = await context.push<DateTime?>('/history/calendar');
    if (selected == null || !mounted) return;
    setState(() {
      _weekAnchor = selected;
      _expandedDay = DateTime(selected.year, selected.month, selected.day);
      _loading = true;
    });
    await _load();
  }

  void _toggleDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _expandedDay = _expandedDay == normalized ? null : normalized;
    });
  }

  AbsenceRequest? _absenceForDay(DateTime day) {
    for (final a in _absences) {
      if (a.coversDay(day)) return a;
    }
    return null;
  }

  void _openForgotClock({DateTime? day}) {
    final initial = day ?? DateTime.now();
    final normalized = DateTime(initial.year, initial.month, initial.day);
    context.push(
      '/incidents/new',
      extra: {
        'mode': 'forgot_clock',
        'proposed_at': normalized.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitleFmt = DateFormat('EEEE, d MMMM yyyy', 'es');
    final rangeFmt = DateFormat('d MMM', 'es');
    final start = weekStart(_weekAnchor);
    final end = weekEnd(_weekAnchor);
    final grouped = groupEventsByDay(_events);
    final weekDays = daysInWeek(_weekAnchor);
    final today = _dayOnly(DateTime.now());

    if (_loading && _events.isEmpty) {
      return const AppLoadingPage();
    }

    return AppPage(
      onRefresh: _load,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppPageHeader(
                title: l10n.timeRecords,
                subtitle: subtitleFmt.format(_weekAnchor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        HistoryQuickLinks(
          incidentsLabel: l10n.myIncidents,
          onIncidentsTap: () => context.push('/incidents'),
          absencesLabel: l10n.myAbsences,
          onAbsencesTap: () => context.push('/ausencias'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.navBar,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _shiftWeek(-1),
                icon: const Icon(
                  CupertinoIcons.chevron_left,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              Expanded(
                child: Text(
                  '${rangeFmt.format(start)} – ${rangeFmt.format(end)}',
                  textAlign: TextAlign.center,
                  style: AppTheme.rowTitle(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: _openCalendar,
                icon: const Icon(
                  CupertinoIcons.calendar,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: () => _shiftWeek(1),
                icon: const Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          AppErrorBanner(message: _error!, onRetry: _load),
          const SizedBox(height: 16),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else
          for (final day in weekDays)
            HistoryDayCard(
              day: day,
              events: grouped[day] ?? const [],
              absence: _absenceForDay(day),
              expanded: _expandedDay == day,
              onToggle: () => _toggleDay(day),
              onForgotClock: day.isAfter(today)
                  ? null
                  : () => _openForgotClock(day: day),
              onEventTap: (event) => context.push(
                '/incidents/new',
                extra: event.toIncidentExtra(),
              ),
              onLocationTap: (event) => showLocationMapSheet(context, event),
            ),
      ],
    );
  }
}
