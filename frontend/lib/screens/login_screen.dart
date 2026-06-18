import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_error.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/screens/register_screen.dart';
import 'package:fitxem/widgets/app_logo.dart';
import 'package:fitxem/widgets/app_page.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Center(child: AppLogo(size: 88)),
                  const SizedBox(height: 24),
                  Text(l10n.appTitle, style: AppTheme.pageTitle(context)),
                  const SizedBox(height: 8),
                  Text(
                    'Control horario para tu equipo',
                    style: AppTheme.subtitle(context),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.softCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _email,
                          decoration: AppTheme.inputDecoration(l10n.email),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _password,
                          decoration: AppTheme.inputDecoration(l10n.password),
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(
                                color: const Color(0xFFFFCDD2),
                              ),
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
                        const SizedBox(height: 24),
                        AppPrimaryButton(
                          label: _loading ? l10n.loading : l10n.login,
                          enabled: !_loading,
                          onTap: _login,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => showRegisterSheet(context, ref),
                    child: Text(
                      l10n.registerOrg,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = apiErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
