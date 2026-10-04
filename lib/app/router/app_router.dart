import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/app/router/home_shell.dart';
import 'package:galeria_eventos/features/calendar/presentation/calendar_page.dart';
import 'package:galeria_eventos/features/settings/presentation/settings_page.dart';
import 'package:galeria_eventos/features/timeline/presentation/timeline_page.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const timeline = '/';
  static const calendar = '/calendar';
  static const settings = '/settings';
}

/// Tres ramas con estado propio (el scroll del timeline se conserva al
/// visitar el calendario). Rutas de detalle (visor, día) se agregan en las
/// fases 5-7 como rutas hijas o de pantalla completa.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.timeline,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.timeline,
                builder: (context, state) => const TimelinePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (context, state) => const CalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
