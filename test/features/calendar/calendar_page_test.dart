import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';
import 'package:go_router/go_router.dart';

import '../../support/fixtures.dart';
import '../../support/test_app.dart';

Future<void> _openCalendar(WidgetTester tester) async {
  await tester.tap(find.text('Calendario'));
  await tester.pumpAndSettle();
}

String _title(int year, int month) => '${EsDateFormat.month(month)} $year';

void main() {
  group('Calendario', () {
    testWidgets('sin recuerdos muestra el estado vacío', (tester) async {
      await tester.pumpWidget(testApp(months: Stream.value(const [])));
      await tester.pumpAndSettle();
      await _openCalendar(tester);

      expect(find.text('Tu calendario de recuerdos'), findsOneWidget);
    });

    testWidgets('abre en el mes más reciente y marca los días con recuerdos', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        testApp(months: septemberBuckets(3), assets: september(3)),
      );
      await tester.pumpAndSettle();
      await _openCalendar(tester);

      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(
        find.bySemanticsLabel('23 de septiembre, 3 recuerdos'),
        findsOneWidget,
      );
      // Un día sin recuerdos solo informa su fecha.
      expect(find.bySemanticsLabel('24 de septiembre'), findsOneWidget);
      // Lunes primero.
      expect(find.text('L'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('las flechas recorren los meses y respetan los extremos', (
      tester,
    ) async {
      final assets = [
        buildAsset('sep', captureDate: DateTime(2026, 9, 5, 9).toUtc()),
        buildAsset('nov', captureDate: DateTime(2026, 11, 5, 9).toUtc()),
      ];
      await tester.pumpWidget(
        testApp(
          months: Stream.value(const [
            MonthBucket(MonthKey(2026, 11), 1),
            MonthBucket(MonthKey(2026, 9), 1),
          ]),
          assets: assets,
        ),
      );
      await tester.pumpAndSettle();
      await _openCalendar(tester);

      expect(find.text('Noviembre 2026'), findsOneWidget);
      IconButton next() => tester.widget(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right),
          matching: find.byType(IconButton),
        ),
      );
      expect(next().onPressed, isNull);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      // Octubre no tiene recuerdos pero está entre los extremos.
      expect(find.text('Octubre 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Septiembre 2026'), findsOneWidget);
      final previous = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_left),
          matching: find.byType(IconButton),
        ),
      );
      expect(previous.onPressed, isNull);
    });

    testWidgets('"Ir a hoy" vuelve al mes actual', (tester) async {
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1, 10, 9);
      final assets = [
        buildAsset('prev', captureDate: previousMonth.toUtc()),
        buildAsset(
          'now',
          captureDate: DateTime(now.year, now.month, 1, 9).toUtc(),
        ),
      ];
      await tester.pumpWidget(
        testApp(
          months: Stream.value([
            MonthBucket(MonthKey(now.year, now.month), 1),
            MonthBucket(MonthKey(previousMonth.year, previousMonth.month), 1),
          ]),
          assets: assets,
        ),
      );
      await tester.pumpAndSettle();
      await _openCalendar(tester);

      expect(find.text('Ir a hoy'), findsNothing);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(
        find.text(_title(previousMonth.year, previousMonth.month)),
        findsOneWidget,
      );

      await tester.tap(find.text('Ir a hoy'));
      await tester.pumpAndSettle();
      expect(find.text(_title(now.year, now.month)), findsOneWidget);
      expect(find.text('Ir a hoy'), findsNothing);
    });

    testWidgets('tocar un día con recuerdos abre sus momentos', (tester) async {
      await tester.pumpWidget(
        testApp(months: septemberBuckets(3), assets: september(3)),
      );
      await tester.pumpAndSettle();
      await _openCalendar(tester);

      await tester.tap(find.text('23'));
      await tester.pumpAndSettle();

      expect(find.textContaining('23 de septiembre'), findsOneWidget);
      expect(find.text('08:00 – 08:10 · 2 fotos, 1 video'), findsOneWidget);
      expect(find.byType(ThumbnailTile), findsNWidgets(3));

      // Volver conserva el calendario en el mismo mes.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Septiembre 2026'), findsOneWidget);
    });

    testWidgets('el detalle del día muestra todos los assets, sin tope', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 4000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(months: septemberBuckets(12), assets: september(12)),
      );
      await tester.pumpAndSettle();
      await _openCalendar(tester);
      await tester.tap(find.text('23'));
      await tester.pumpAndSettle();

      expect(find.byType(ThumbnailTile), findsNWidgets(12));
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('un día sin recuerdos no es tocable', (tester) async {
      await tester.pumpWidget(
        testApp(months: septemberBuckets(3), assets: september(3)),
      );
      await tester.pumpAndSettle();
      await _openCalendar(tester);

      await tester.tap(find.text('24'));
      await tester.pumpAndSettle();

      expect(find.text('Septiembre 2026'), findsOneWidget);
    });

    testWidgets('una fecha inválida en la ruta muestra un aviso', (
      tester,
    ) async {
      await tester.pumpWidget(testApp(months: Stream.value(const [])));
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(Scaffold).first),
      ).go('/calendar/day/2026-02-31');
      await tester.pumpAndSettle();

      expect(find.text('Esa fecha no es válida'), findsOneWidget);
    });

    testWidgets('un día sin assets (enlace antiguo) lo indica', (tester) async {
      await tester.pumpWidget(testApp(months: Stream.value(const [])));
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(Scaffold).first),
      ).go('/calendar/day/2026-09-23');
      await tester.pumpAndSettle();

      expect(find.text('Sin recuerdos este día'), findsOneWidget);
    });
  });
}
