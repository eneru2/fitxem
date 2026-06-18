import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fitxem/theme/app_theme.dart';

class AppEventRow extends StatelessWidget {
  const AppEventRow({
    super.key,
    required this.type,
    required this.label,
    required this.time,
    this.highlighted = false,
    this.badge,
    this.showDivider = true,
    this.onTap,
  });

  final String? type;
  final String label;
  final String time;
  final bool highlighted;
  final String? badge;
  final bool showDivider;
  final VoidCallback? onTap;

  IconData _icon() {
    switch (type) {
      case 'in':
        return CupertinoIcons.play_fill;
      case 'out':
        return CupertinoIcons.stop_fill;
      case 'break_start':
        return CupertinoIcons.pause_fill;
      case 'break_end':
        return CupertinoIcons.play_fill;
      default:
        return CupertinoIcons.clock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = AppTheme.eventIconColor(type);
    final bgAlpha = highlighted ? 0.16 : 0.09;

    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, indent: 68, color: AppTheme.border),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: bgAlpha),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    _icon(),
                    size: 17,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 14),
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
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(badge!, style: AppTheme.badge(context)),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
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
