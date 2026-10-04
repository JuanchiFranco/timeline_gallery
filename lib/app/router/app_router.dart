import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/app/router/home_shell.dart';
import 'package:galeria_eventos/features/calendar/domain/calendar.dart';
import 'package:galeria_eventos/features/calendar/presentation/calendar_page.dart';
import 'package:galeria_eventos/features/calendar/presentation/day_page.dart';
import 'package:galeria_eventos/features/settings/presentation/settings_page.dart';
import 'package:galeria_eventos/features/timeline/presentation/timeline_page.dart';
import 'package:galeria_eventos/features/viewer/domain/viewer.dart';
import 'package:galeria_eventos/features/viewer/presentation/viewer_page.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const timeline = '/';
  static const calendar = '/calendar';
  static const settings = '/settings';
}

/// Tres ramas con estado propio (el scroll del timeline se conserva al
/// visitar el calendario). El detalle de un día es hija de Calendario; el
/// visor de fotos y videos es una ruta de pantalla completa fuera del shell.
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
                routes: [
                  GoRoute(
                    path: 'day/:date',
                    builder: (context, state) {
                      final date = parseDayParam(state.pathParameters['date']!);
                      return date == null
                          ? const InvalidDayPage()
                          : DayPage(date: date);
                    },
                  ),
                ],
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
      // Fuera del shell: el visor ocupa toda la pantalla, sin barra inferior.
      GoRoute(
        path: '/viewer/:date/:assetId',
        builder: (context, state) {
          final dayParam = state.pathParameters['date']!;
          return ViewerDay.parse(dayParam) is InvalidViewerDay
              ? const InvalidDayPage()
              : ViewerPage(
                  dayParam: dayParam,
                  assetId: state.pathParameters['assetId']!,
                );
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
