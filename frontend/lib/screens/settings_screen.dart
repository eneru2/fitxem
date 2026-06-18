import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/widgets/app_page.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _org;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final org = await ref.read(apiClientProvider).getOrg();
      if (mounted) setState(() => _org = org);
    } catch (_) {}
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
                    title: 'Plan',
                    subtitle: _org!['subscription_tier'] as String? ?? 'trial',
                    icon: CupertinoIcons.creditcard,
                    showDivider: false,
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
