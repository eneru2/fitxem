import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/theme/app_theme.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.padding,
    this.physics,
    this.onRefresh,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final listView = ListView(
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.pageTopPadding,
            AppTheme.pagePadding,
            32,
          ),
      children: children,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: onRefresh == null
            ? listView
            : RefreshIndicator(
                onRefresh: onRefresh!,
                child: listView,
              ),
      ),
    );
  }
}

class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: CupertinoActivityIndicator(radius: 12)),
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: AppTheme.greeting(context)),
          const SizedBox(height: 4),
        ],
        Text(title, style: AppTheme.pageTitle(context)),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: AppTheme.subtitle(context)),
        ],
      ],
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.showDivider = true,
  });

  final String title;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) ...[
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
        ],
        Text(title, style: AppTheme.sectionTitle(context)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class AppSoftCard extends StatelessWidget {
  const AppSoftCard({super.key, required this.child, this.clip = true});

  final Widget child;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.softCard(),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = CupertinoIcons.clock,
    this.wrapped = true,
  });

  final String message;
  final IconData icon;
  final bool wrapped;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTheme.subtitle(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (!wrapped) return content;
    return AppSoftCard(child: content);
  }
}

class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFFC2410C)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTheme.subtitle(context).copyWith(
                color: const Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.bordered(),
      child: Row(
        children: [
          Expanded(child: Text(message, style: AppTheme.subtitle(context))),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.style,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: style ?? AppTheme.filledButtonStyle(),
        child: Text(label),
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: AppTheme.outlinedButtonStyle(),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        destructive ? const Color(0xFFE53935) : AppTheme.textPrimary;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: destructive
                          ? const Color(0xFFE53935)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.rowTitle(context)
                            .copyWith(color: titleColor),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTheme.rowMeta(context)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (onTap != null && trailing == null)
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 70, color: AppTheme.border),
      ],
    );
  }
}

class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppTheme.surface
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusPill - 4),
                    border: selectedIndex == i
                        ? Border.all(color: AppTheme.border)
                        : null,
                    boxShadow: selectedIndex == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selectedIndex == i
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: selectedIndex == i
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
