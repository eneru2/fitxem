import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/services/location_service.dart';
import 'package:fitxem/services/linux_location_banner.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<dynamic> _events = [];
  int _workedSeconds = 0;
  DateTime _fetchedAt = DateTime.now();
  bool _initialLoading = true;
  String? _error;
  Timer? _tickTimer;
  final ScrollController _listScrollController = ScrollController();
  double? _sheetExtent;
  bool _sheetDragging = false;

  static const _sheetAnimDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onSheetPanStart() => setState(() => _sheetDragging = true);

  void _onSheetPanCancel() => setState(() => _sheetDragging = false);

  void _onSheetPanUpdate(
    DragUpdateDetails details,
    double sheetHeight,
    List<double> snapSizes,
  ) {
    setState(() {
      _sheetExtent = (_sheetExtent! - details.delta.dy / sheetHeight).clamp(
        snapSizes.first,
        snapSizes.last,
      );
    });
  }

  void _onSheetPanEnd(DragEndDetails details, List<double> snapSizes) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final current = _sheetExtent!;
    final min = snapSizes.first;
    final max = snapSizes.last;

    late final double target;
    if (velocity.abs() > 400) {
      if (velocity < 0) {
        target = snapSizes.firstWhere(
          (s) => s > current + 0.001,
          orElse: () => max,
        );
      } else {
        target = snapSizes.lastWhere(
          (s) => s < current - 0.001,
          orElse: () => min,
        );
      }
    } else {
      target = snapSizes.reduce(
        (a, b) => (current - a).abs() < (current - b).abs() ? a : b,
      );
    }

    setState(() {
      _sheetDragging = false;
      _sheetExtent = target;
    });
  }

  void _collapseSheet(double minSize) {
    setState(() => _sheetExtent = minSize);
  }

  double _backdropOpacity(double extent, double minSize, double maxSize) {
    if (extent <= minSize) return 0;
    return ((extent - minSize) / (maxSize - minSize)).clamp(0.0, 1.0) * 0.45;
  }

  bool get _isWorking {
    if (_events.isEmpty) return false;
    switch ((_events.last as Map<String, dynamic>)['event_type']) {
      case 'in':
      case 'break_end':
        return true;
      default:
        return false;
    }
  }

  int get _displayWorkedSeconds {
    var seconds = _workedSeconds;
    if (_isWorking) {
      seconds += DateTime.now().difference(_fetchedAt).inSeconds;
    }
    return seconds;
  }

  void _updateTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (!_isWorking) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _error = null);
    }
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.todayStatus();
      if (!mounted) return;
      setState(() {
        _events = List<dynamic>.from(data['events'] as List? ?? []);
        _workedSeconds = (data['worked_seconds'] as num?)?.toInt() ?? 0;
        final asOf = data['as_of'] as String?;
        _fetchedAt = asOf != null
            ? DateTime.parse(asOf).toLocal()
            : DateTime.now();
      });
      _updateTickTimer();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_events.isEmpty) return l10n.statusOut;
    switch ((_events.last as Map<String, dynamic>)['event_type']) {
      case 'in':
      case 'break_end':
        return l10n.statusWorking;
      case 'break_start':
        return l10n.statusBreak;
      case 'out':
        return l10n.statusOut;
      default:
        return l10n.statusOut;
    }
  }

  _ClockAction? _primaryAction(AppLocalizations l10n) {
    final status = _statusLabel(l10n);
    if (status == l10n.statusWorking) {
      return _ClockAction(
        label: l10n.clockOut,
        endpoint: 'out',
        icon: CupertinoIcons.square_arrow_right,
      );
    }
    if (status == l10n.statusBreak) {
      return _ClockAction(
        label: l10n.breakEnd,
        endpoint: 'break/end',
        icon: CupertinoIcons.play_fill,
      );
    }
    return _ClockAction(
      label: l10n.clockIn,
      endpoint: 'in',
      icon: CupertinoIcons.play_fill,
    );
  }

  List<_ClockAction> _moreActions(AppLocalizations l10n) {
    final status = _statusLabel(l10n);
    if (status == l10n.statusWorking) {
      return [
        _ClockAction(
          label: l10n.breakStart,
          endpoint: 'break/start',
          icon: Icons.coffee_outlined,
        ),
      ];
    }
    return [];
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'BUENOS DÍAS';
    if (hour < 20) return 'BUENAS TARDES';
    return 'BUENAS NOCHES';
  }

  String _displayName(String? email) {
    if (email == null || email.isEmpty) return '';
    final local = email.split('@').first;
    final parts = local.split('.');
    if (parts.length > 1) {
      return parts
          .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }
    final part = local;
    if (part.isEmpty) return local;
    return part[0].toUpperCase() + part.substring(1);
  }

  String _pageHeading(String? email, AppLocalizations l10n) {
    final name = _displayName(email);
    return name.isEmpty ? l10n.appTitle : name;
  }

  String? _lastClockInTime(DateFormat timeFmt) {
    for (var i = _events.length - 1; i >= 0; i--) {
      final type =
          (_events[i] as Map<String, dynamic>)['event_type'] as String?;
      if (type == 'in' || type == 'break_end') {
        return timeFmt.format(
          DateTime.parse(
            (_events[i] as Map<String, dynamic>)['recorded_at'] as String,
          ).toLocal(),
        );
      }
    }
    return null;
  }

  String _formatWorkedDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  Future<void> _clock(String endpoint) async {
    HapticFeedback.lightImpact();
    try {
      final location =
          await ref.read(locationServiceProvider).capturePosition();
      await ref.read(apiClientProvider).clock(
            endpoint,
            latitude: location.position?.latitude,
            longitude: location.position?.longitude,
          );
      await _load(silent: true);
      if (!mounted) return;
      if (location.status == LocationCaptureStatus.skippedImprecise) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.locationSkippedImprecise)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final linuxLocationBanner = ref.watch(linuxLocationBannerProvider);
    final locationBannerMessage = linuxLocationBanner.maybeWhen(
      data: (LinuxLocationBanner banner) {
        return switch (banner) {
          LinuxLocationBanner.geoclueUnavailable =>
            l10n.locationUnavailableGeoClue,
          LinuxLocationBanner.locationDisabled => l10n.locationDisabledLinux,
          LinuxLocationBanner.desktopUnreliable =>
            l10n.locationDesktopUnreliableLinux,
          LinuxLocationBanner.none => null,
        };
      },
      orElse: () => null,
    );
    final dateFmt = DateFormat('EEEE, d MMMM', 'es');
    final timeFmt = DateFormat('HH:mm');
    final status = _statusLabel(l10n);
    final primary = _primaryAction(l10n);
    final more = _moreActions(l10n);
    final clockInTime = _lastClockInTime(timeFmt);
    final isWorking = status == l10n.statusWorking;

    if (_initialLoading) return const AppLoadingPage();

    final workedSeconds = _displayWorkedSeconds;
    final hours = (workedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((workedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (workedSeconds % 60).toString().padLeft(2, '0');
    final now = DateTime.now();

    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bodyHeight = constraints.maxHeight;
            final sheetHeight = bodyHeight;
            final snapSizes = [0.42, 0.65, 0.92];
            final minSize = snapSizes.first;
            final maxSize = snapSizes.last;
            _sheetExtent ??= minSize;
            final backdropOpacity = _backdropOpacity(
              _sheetExtent!,
              minSize,
              maxSize,
            );
            final sheetAnimDuration = _sheetDragging
                ? Duration.zero
                : _sheetAnimDuration;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.pageTopPadding,
                    AppTheme.pagePadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: AppTheme.greeting(context),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _pageHeading(auth.email, l10n),
                                  style: AppTheme.pageTitle(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _capitalize(dateFmt.format(now)),
                                  style: AppTheme.subtitle(context),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(
                            label: status.toUpperCase(),
                            isActive: isWorking || status == l10n.statusBreak,
                            isWorking: isWorking,
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      _TimerDisplay(
                        hours: hours,
                        minutes: minutes,
                        seconds: seconds,
                      ),
                      if (clockInTime != null && status != l10n.statusOut) ...[
                        const SizedBox(height: 16),
                        Center(child: _EntryPill(time: clockInTime)),
                      ],
                      const SizedBox(height: 28),
                      if (locationBannerMessage != null) ...[
                        AppInfoBanner(
                          message: locationBannerMessage,
                          icon: CupertinoIcons.location_slash,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (primary != null)
                        _ActionButtonRow(
                          primary: primary,
                          secondary: more.isNotEmpty ? more.first : null,
                          onPrimary: () => _clock(primary.endpoint),
                          onSecondary: more.isNotEmpty
                              ? () => _clock(more.first.endpoint)
                              : null,
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        AppErrorBanner(message: _error!, onRetry: _load),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: backdropOpacity == 0,
                    child: GestureDetector(
                      onTap: () => _collapseSheet(minSize),
                      child: AnimatedContainer(
                        duration: sheetAnimDuration,
                        curve: Curves.easeOut,
                        color: Colors.black.withValues(alpha: backdropOpacity),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: sheetAnimDuration,
                    curve: Curves.easeOut,
                    height: sheetHeight * _sheetExtent!,
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    clipBehavior: Clip.none,
                    child: _ActivityPanel(
                      title: l10n.todayActivity.toUpperCase(),
                      workedLabel: _formatWorkedDuration(workedSeconds),
                      bottomPadding: 16,
                      onPanStart: _onSheetPanStart,
                      onPanCancel: _onSheetPanCancel,
                      onPanUpdate: (details) =>
                          _onSheetPanUpdate(details, sheetHeight, snapSizes),
                      onPanEnd: (details) => _onSheetPanEnd(details, snapSizes),
                      child: _events.isEmpty
                          ? ListView(
                              controller: _listScrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              children: [
                                AppEmptyState(
                                  message: l10n.noEvents,
                                  wrapped: false,
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _listScrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              itemCount: _events.length,
                              itemBuilder: (context, i) {
                                final event =
                                    _events[i] as Map<String, dynamic>;
                                final type = event['event_type'] as String?;
                                final isLast = i == _events.length - 1;
                                final isActive =
                                    isLast &&
                                    (type == 'in' || type == 'break_end');
                                return _TimelineEventRow(
                                  type: type,
                                  label: _eventLabel(type, l10n),
                                  time: timeFmt.format(
                                    DateTime.parse(
                                      event['recorded_at'] as String,
                                    ).toLocal(),
                                  ),
                                  trailing: isActive
                                      ? _InProgressBadge(label: l10n.inProgress)
                                      : _eventTrailing(type, l10n),
                                  showLine: i < _events.length - 1,
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget? _eventTrailing(String? type, AppLocalizations l10n) {
    return switch (type) {
      'break_start' => Text(l10n.breakStart, style: AppTheme.rowMeta(context)),
      'out' when _events.length > 1 => Text(
        l10n.breakStart,
        style: AppTheme.rowMeta(context),
      ),
      _ => null,
    };
  }

  String _eventLabel(String? type, AppLocalizations l10n) {
    switch (type) {
      case 'in':
        return l10n.clockIn;
      case 'out':
        return l10n.clockOut;
      case 'break_start':
        return l10n.breakStart;
      case 'break_end':
        return l10n.clockIn;
      default:
        return type ?? '';
    }
  }
}

class _ClockAction {
  const _ClockAction({
    required this.label,
    required this.endpoint,
    required this.icon,
  });

  final String label;
  final String endpoint;
  final IconData icon;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isActive,
    required this.isWorking,
  });

  final String label;
  final bool isActive;
  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    final bg = isWorking
        ? AppTheme.greenMuted
        : isActive
        ? AppTheme.surfaceMuted
        : AppTheme.surfaceMuted;
    final dot = isWorking ? AppTheme.green : AppTheme.textTertiary;
    final text = isWorking ? AppTheme.greenText : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final String hours;
  final String minutes;
  final String seconds;

  TextStyle _mainStyle() => GoogleFonts.outfit(
    fontSize: 64,
    fontWeight: FontWeight.w700,
    letterSpacing: -3,
    color: AppTheme.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1,
  );

  TextStyle _secondsStyle() => GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: -1,
    color: AppTheme.textSecondary,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$hours:$minutes', style: _mainStyle()),
          Text(':$seconds', style: _secondsStyle()),
        ],
      ),
    );
  }
}

class _EntryPill extends StatelessWidget {
  const _EntryPill({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          children: [
            const TextSpan(text: 'Entrada a las '),
            TextSpan(
              text: time,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonRow extends StatelessWidget {
  const _ActionButtonRow({
    required this.primary,
    this.secondary,
    required this.onPrimary,
    this.onSecondary,
  });

  final _ClockAction primary;
  final _ClockAction? secondary;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    if (secondary == null) {
      return _ActionButton(
        label: primary.label,
        icon: primary.icon,
        filled: true,
        onTap: onPrimary,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: primary.label,
            icon: primary.icon,
            filled: true,
            onTap: onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: secondary!.label,
            icon: secondary!.icon,
            filled: false,
            onTap: onSecondary!,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppTheme.textPrimary : AppTheme.surface,
      elevation: filled ? 0 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          height: 56,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? Colors.white : AppTheme.textPrimary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.title,
    required this.workedLabel,
    required this.bottomPadding,
    required this.onPanStart,
    required this.onPanCancel,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.child,
  });

  final String title;
  final String workedLabel;
  final double bottomPadding;
  final VoidCallback onPanStart;
  final VoidCallback onPanCancel;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetGrabHandle(
          onPanStart: onPanStart,
          onPanCancel: onPanCancel,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: AppTheme.sectionTitle(context)),
              ),
              Text(
                workedLabel,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
        SizedBox(height: bottomPadding),
      ],
    );
  }
}

class _SheetGrabHandle extends StatefulWidget {
  const _SheetGrabHandle({
    required this.onPanStart,
    required this.onPanCancel,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.child,
  });

  final VoidCallback onPanStart;
  final VoidCallback onPanCancel;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final Widget child;

  @override
  State<_SheetGrabHandle> createState() => _SheetGrabHandleState();
}

class _SheetGrabHandleState extends State<_SheetGrabHandle> {
  bool _grabbing = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _grabbing ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          setState(() => _grabbing = true);
          widget.onPanStart();
        },
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: (details) {
          setState(() => _grabbing = false);
          widget.onPanEnd(details);
        },
        onPanCancel: () {
          setState(() => _grabbing = false);
          widget.onPanCancel();
        },
        child: widget.child,
      ),
    );
  }
}

class _InProgressBadge extends StatelessWidget {
  const _InProgressBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.greenMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.greenText,
        ),
      ),
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({
    required this.type,
    required this.label,
    required this.time,
    this.trailing,
    this.showLine = true,
  });

  final String? type;
  final String label;
  final String time;
  final Widget? trailing;
  final bool showLine;

  IconData _icon() {
    switch (type) {
      case 'in':
      case 'break_end':
        return CupertinoIcons.play_fill;
      case 'out':
        return CupertinoIcons.stop_fill;
      case 'break_start':
        return CupertinoIcons.pause_fill;
      default:
        return CupertinoIcons.clock;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon(), size: 13, color: AppTheme.textSecondary),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppTheme.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTheme.rowTitle(context)),
                        const SizedBox(height: 2),
                        Text(time, style: AppTheme.rowMeta(context)),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
