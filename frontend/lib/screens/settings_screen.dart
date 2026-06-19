import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/billing_plan.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/services/reminder_service.dart';
import 'package:fitxem/widgets/app_page.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _org;
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (!notificationsSupported) return;
    final enabled = await ref.read(reminderServiceProvider).isEnabled();
    if (mounted) setState(() => _remindersEnabled = enabled);
  }

  Future<void> _load() async {
    try {
      final org = await ref.read(apiClientProvider).getOrg();
      if (mounted) setState(() => _org = org);
    } catch (_) {}
  }

  String _planSubtitle() {
    final tier = _org?['subscription_tier'] as String? ?? 'trial';
    final label = BillingPlan.subscriptionLabel(tier);
    if (tier == 'trial') return '$label · Mejorar plan';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);

    return AppPage(
      children: [
        AppPageHeader(title: l10n.settings),
        const SizedBox(height: 28),
        if (_org != null) ...[
          AppSection(
            title: 'Organización',
            showDivider: false,
            child: AppSoftCard(
              child: Column(
                children: [
                  AppSettingsRow(
                    title: _org!['legal_name'] as String? ?? '',
                    subtitle: 'CIF ${_org!['cif']}',
                    icon: CupertinoIcons.building_2_fill,
                    showDivider: true,
                  ),
                  AppSettingsRow(
                    title: 'Plan y facturación',
                    subtitle: _planSubtitle(),
                    icon: CupertinoIcons.creditcard,
                    showDivider: false,
                    onTap: () => context.push('/settings/billing'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        AppSection(
          title: 'Cuenta',
          showDivider: _org != null,
          child: AppSoftCard(
            child: AppSettingsRow(
              title: auth.email ?? '',
              subtitle: auth.isAdmin ? 'Administrador' : 'Empleado',
              icon: CupertinoIcons.person,
              showDivider: false,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (notificationsSupported) ...[
          AppSection(
            title: 'Notificaciones',
            child: AppSoftCard(
              child: AppSettingsRow(
                title: 'Recordatorios de fichaje',
                subtitle: 'Aviso a +5, +10 y +15 min si no has fichado',
                icon: CupertinoIcons.bell,
                showDivider: false,
                trailing: Switch(
                  value: _remindersEnabled,
                  onChanged: (v) async {
                    setState(() => _remindersEnabled = v);
                    await ref.read(reminderServiceProvider).setEnabled(v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        AppSection(
          title: 'Sesión',
          child: AppSoftCard(
            child: AppSettingsRow(
              title: l10n.logout,
              icon: CupertinoIcons.arrow_right_square,
              destructive: true,
              showDivider: false,
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ),
      ],
    );
  }
}
