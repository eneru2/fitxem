import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_error.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';

Future<void> showRegisterSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RegisterSheet(
      onRegister: (data) => ref.read(authProvider.notifier).registerOrg(data),
      onSuccess: onSuccess ?? () => context.go('/'),
    ),
  );
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAndLeave());
  }

  Future<void> _openAndLeave() async {
    await showRegisterSheet(context, ref);
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: SizedBox.shrink(),
    );
  }
}

class _RegisterSheet extends StatefulWidget {
  const _RegisterSheet({
    required this.onRegister,
    required this.onSuccess,
  });

  final Future<void> Function(Map<String, String> data) onRegister;
  final VoidCallback onSuccess;

  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _cif = TextEditingController();
  final _legalName = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerNif = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _cif.dispose();
    _legalName.dispose();
    _ownerName.dispose();
    _ownerNif.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onRegister({
        'cif': _cif.text.trim(),
        'legal_name': _legalName.text.trim(),
        'owner_name': _ownerName.text.trim(),
        'owner_nif': _ownerNif.text.trim(),
        'owner_email': _email.text.trim(),
        'owner_password': _password.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
          ),
          child: SafeArea(
            top: false,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.registerOrg,
                          style: AppTheme.pageTitle(context),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          CupertinoIcons.xmark,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    'Crea tu organización y empieza a fichar.',
                    style: AppTheme.subtitle(context),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    children: [
                      TextField(
                        controller: _cif,
                        decoration: AppTheme.inputDecoration(l10n.cif),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _legalName,
                        decoration: AppTheme.inputDecoration(l10n.legalName),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _ownerName,
                        decoration: AppTheme.inputDecoration(l10n.ownerName),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _ownerNif,
                        decoration: AppTheme.inputDecoration(l10n.ownerNif),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _email,
                        decoration: AppTheme.inputDecoration(l10n.email),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        decoration: AppTheme.inputDecoration(l10n.password),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFC62828),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPrimaryButton(
                        label: _submitting ? l10n.loading : l10n.registerOrg,
                        enabled: !_submitting,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 10),
                      AppSecondaryButton(
                        label: 'Cancelar',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
