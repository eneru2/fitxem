import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/clock_event.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/utils/time_grouping.dart';
import 'package:fitxem/widgets/app_page.dart';

class HistoryCalendarScreen extends ConsumerStatefulWidget {
  const HistoryCalendarScreen({super.key});

  @override
  ConsumerState<HistoryCalendarScreen> createState() =>
      _HistoryCalendarScreenState();
}

class _HistoryCalendarScreenState extends ConsumerState<HistoryCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<ClockEvent> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonth(_focusedDay);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final first = DateTime(month.year, month.month, 1);
      final last = DateTime(month.year, month.month + 1, 0);
      final from = first.subtract(const Duration(days: 7));
      final to = DateTime(last.year, last.month, last.day, 23, 59, 59, 999)
          .add(const Duration(days: 7));
      final events = await ref.read(apiClientProvider).myRecords(
            from: from.toUtc().toIso8601String(),
            to: to.toUtc().toIso8601String(),
          );
      if (!mounted) return;
      setState(() => _events = events);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<DateTime, List<ClockEvent>> get _grouped => groupEventsByDay(_events);

  bool _hasCorrection(DateTime day) {
    final events = _grouped[DateTime(day.year, day.month, day.day)];
    return events?.any((e) => e.isCorrection) ?? false;
  }

  List<String> _workCentersForDay(DateTime day) {
    final events = _grouped[DateTime(day.year, day.month, day.day)] ?? [];
    final names = <String>{};
    for (final ev in events) {
      if (ev.workCenter != null && ev.workCenter!.isNotEmpty) {
        names.add(ev.workCenter!);
      }
    }
    return names.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitleFmt = DateFormat('EEEE, d MMMM yyyy', 'es');
    final monthFmt = DateFormat.MMMM('es');
    final years = List.generate(
      11,
      (i) => DateTime.now().year - 5 + i,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.pageTopPadding,
            AppTheme.pagePadding,
            32,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(CupertinoIcons.back),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        l10n.calendar,
                        style: AppTheme.pageTitle(context).copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleFmt.format(_selectedDay),
                        style: AppTheme.subtitle(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('month-${_focusedDay.year}-${_focusedDay.month}'),
                    initialValue: _focusedDay.month,
                    decoration: AppTheme.inputDecoration(l10n.month),
                    items: List.generate(12, (i) {
                      final month = DateTime(2026, i + 1);
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(monthFmt.format(month)),
                      );
                    }),
                    onChanged: (month) {
                      if (month == null) return;
                      final next = DateTime(_focusedDay.year, month);
                      setState(() => _focusedDay = next);
                      _loadMonth(next);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('year-${_focusedDay.year}'),
                    initialValue: _focusedDay.year,
                    decoration: AppTheme.inputDecoration(l10n.year),
                    items: years
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text('$y'),
                          ),
                        )
                        .toList(),
                    onChanged: (year) {
                      if (year == null) return;
                      final next = DateTime(year, _focusedDay.month);
                      setState(() => _focusedDay = next);
                      _loadMonth(next);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              AppErrorBanner(message: _error!, onRetry: () => _loadMonth(_focusedDay)),
              const SizedBox(height: 16),
            ],
            DecoratedBox(
              decoration: AppTheme.softCard(radius: AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TableCalendar<ClockEvent>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  locale: 'es',
                  calendarFormat: CalendarFormat.month,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  headerVisible: false,
                  eventLoader: (day) =>
                      _grouped[DateTime(day.year, day.month, day.day)] ?? [],
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                    _loadMonth(focusedDay);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.greenMuted,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: AppTheme.rowTitle(context).copyWith(
                      color: AppTheme.greenText,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: AppTheme.rowTitle(context).copyWith(
                      color: Colors.white,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.green,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 1,
                    outsideDaysVisible: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasCorrection(day))
                              const Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  size: 8,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            const SizedBox(height: 20),
            Text(l10n.daySummary, style: AppTheme.sectionTitle(context)),
            const SizedBox(height: 12),
            if (_workCentersForDay(_selectedDay).isEmpty)
              AppEmptyState(
                message: l10n.noRecordsForDay,
                icon: CupertinoIcons.doc_text,
              )
            else
              for (final name in _workCentersForDay(_selectedDay))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name, style: AppTheme.rowTitle(context)),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(_selectedDay),
              child: Text(l10n.goToDay),
            ),
          ],
        ),
      ),
    );
  }
}
