import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/screens/absence_create_screen.dart';
import 'package:fitxem/screens/ausencias_screen.dart';
import 'package:fitxem/screens/incident_create_screen.dart';
import 'package:fitxem/screens/incidents_screen.dart';
import 'package:fitxem/screens/admin_screen.dart';
import 'package:fitxem/screens/history_calendar_screen.dart';
import 'package:fitxem/screens/history_screen.dart';
import 'package:fitxem/screens/home_screen.dart';
import 'package:fitxem/screens/login_screen.dart';
import 'package:fitxem/screens/register_screen.dart';
import 'package:fitxem/screens/settings_screen.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_bottom_bar.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!auth.isAuthenticated && !loggingIn) return '/login';
      if (auth.isAuthenticated && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/correction-request',
        redirect: (_, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final mode = extra['mode'] as String? ??
                extra['scenario'] as String? ??
                'forgot_clock';
            return Uri(
              path: '/incidents/new',
              queryParameters: {'mode': mode},
            ).toString();
          }
          return '/incidents/new?mode=forgot_clock';
        },
      ),
      GoRoute(
        path: '/incidents',
        builder: (_, __) => const IncidentsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final extra = state.extra;
              final queryMode = state.uri.queryParameters['mode'];
              if (extra is Map<String, dynamic>) {
                final at = extra['proposed_at'] as String?;
                final mode = extra['mode'] as String? ??
                    extra['scenario'] as String? ??
                    queryMode ??
                    'forgot_clock';
                return IncidentCreateScreen(
                  mode: mode,
                  initialEventType: extra['event_type'] as String?,
                  initialProposedAt:
                      at != null ? DateTime.parse(at).toLocal() : null,
                  relatedEventId: extra['related_event_id'] as String?,
                );
              }
              return IncidentCreateScreen(
                mode: queryMode ?? 'forgot_clock',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/ausencias',
        builder: (_, __) => const AusenciasScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const AbsenceCreateScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, __) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: 'calendar',
                    builder: (_, __) => const HistoryCalendarScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navigationShell.currentIndex == 0
          ? AppTheme.surface
          : AppTheme.background,
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
