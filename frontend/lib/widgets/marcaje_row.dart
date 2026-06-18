import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/clock_event.dart';
import 'package:fitxem/theme/app_theme.dart';

class MarcajeRow extends StatelessWidget {
  const MarcajeRow({
    super.key,
    required this.event,
    this.showDivider = true,
    this.onTap,
    this.onLocationTap,
  });

  final ClockEvent event;
  final bool showDivider;
  final VoidCallback? onTap;
  final VoidCallback? onLocationTap;

  IconData _typeIcon() {
    switch (event.eventType) {
      case 'in':
        return CupertinoIcons.arrow_right_to_line;
      case 'out':
        return CupertinoIcons.arrow_left_to_line;
      case 'break_start':
        return CupertinoIcons.pause_fill;
      case 'break_end':
        return CupertinoIcons.play_fill;
      default:
        return CupertinoIcons.clock;
    }
  }

  Color _typeColor() {
    switch (event.eventType) {
      case 'in':
      case 'break_end':
        return const Color(0xFF14B8A6);
      case 'out':
        return const Color(0xFFEC4899);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeFmt = DateFormat('HH:mm');

    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, indent: 52, color: AppTheme.border),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (onLocationTap != null)
                  IconButton(
                    onPressed: onLocationTap,
                    icon: const Icon(
                      CupertinoIcons.location,
                      size: 18,
                      color: AppTheme.textTertiary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const SizedBox(width: 8),
                Icon(_typeIcon(), size: 16, color: _typeColor()),
                const SizedBox(width: 10),
                Text(
                  timeFmt.format(event.recordedAt),
                  style: AppTheme.rowTitle(context).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                if (event.isCorrection) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.approvedIncidentBadge,
                      style: AppTheme.rowMeta(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                if (onTap != null) ...[
                  Text(
                    l10n.tapFichajeHint,
                    style: AppTheme.rowMeta(context).copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
