import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/app/app.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';

import '../../../support/fakes.dart';
import '../../../support/fixtures.dart';
import '../../../support/test_app.dart';

/// Índice que cuenta cuántas veces se consultaron assets de un rango.
class _CountingIndex extends FakeMediaIndexRepository {
  _CountingIndex(super.assets);

  int rangeQueries = 0;

  @override
  Stream<List<MediaAsset>> watchRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    rangeQueries++;
    return super.watchRange(
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
    );
  }
}

/// Índice cuyas consultas de assets no responden nunca (días "cargando").
class _NeverAnswersIndex extends FakeMediaIndexRepository {
  _NeverAnswersIndex(super.assets);

  final _controllers = <StreamController<List<MediaAsset>>>[];

  @override
  Stream<List<MediaAsset>> watchRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    final controller = StreamController<List<MediaAsset>>();
    _controllers.add(controller);
    return controller.stream;
  }

  Future<void> close() => Future.wait(_controllers.map((c) => c.close()));
}

/// Un asset por día durante [days] días, el más reciente primero en la lista.
List<MediaAsset> _oneAssetPerDay(int days) => [
  for (var i = 0; i < days; i++)
    buildAsset('d$i', captureDate: DateTime(2024, 1, 1 + i, 12).toUtc()),
];

void main() {
  group('la lista se construye de forma perezosa', () {
    testWidgets('con 400 días solo se consultan los que están en pantalla', (
      tester,
    ) async {
      final index = _CountingIndex(_oneAssetPerDay(400));

      await tester.pumpWidget(testApp(index: index));
      await tester.pumpAndSettle();

      expect(index.rangeQueries, greaterThan(0));
      expect(index.rangeQueries, lessThan(25));
      expect(find.byType(ThumbnailTile).evaluate().length, lessThan(25));
    });

    testWidgets('un mes con miles de fotos construye solo lo visible', (
      tester,
    ) async {
      // 30 días x 100 fotos en 4 momentos de 25: antes se construía el mes
      // entero (más de 800 miniaturas).
      final assets = [
        for (var d = 0; d < 30; d++)
          for (var m = 0; m < 4; m++)
            for (var i = 0; i < 25; i++)
              buildAsset(
                'h$d-$m-$i',
                captureDate: DateTime(2025, 7, 1 + d, 8 + m * 3, i * 2).toUtc(),
              ),
      ];
      final index = _CountingIndex(assets);

      await tester.pumpWidget(testApp(index: index, assets: assets));
      await tester.pumpAndSettle();

      expect(find.text('Julio · 3000'), findsOneWidget);
      expect(find.byType(ThumbnailTile).evaluate().length, lessThan(60));
      expect(index.rangeQueries, lessThan(10));
    });

    testWidgets('al hacer scroll se van pidiendo más días', (tester) async {
      final index = _CountingIndex(_oneAssetPerDay(400));
      await tester.pumpWidget(testApp(index: index));
      await tester.pumpAndSettle();
      final before = index.rangeQueries;

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(index.rangeQueries, greaterThan(before));
    });

    testWidgets('el día que sale de pantalla suelta su consulta', (
      tester,
    ) async {
      final index = _CountingIndex(_oneAssetPerDay(400));
      await tester.pumpWidget(testApp(index: index));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GaleriaApp)),
      );
      // El día más reciente (el primero de la lista) ya no está construido.
      final newest = DateTime(2024, 1, 1 + 399);
      expect(container.exists(dayMomentsProvider(newest)), isFalse);
    });
  });

  group('altura reservada de cada día', () {
    testWidgets('al cargar un día recuerda su altura real', (tester) async {
      await tester.pumpWidget(testApp(assets: _oneAssetPerDay(3)));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GaleriaApp)),
      );
      final cache = container.read(dayHeightCacheProvider);

      expect(cache, isNotEmpty);
      expect(cache.values, everyElement(greaterThan(0)));
    });

    testWidgets('mientras un día carga, reserva la altura que tuvo antes', (
      tester,
    ) async {
      final assets = _oneAssetPerDay(1);
      final index = _NeverAnswersIndex(assets);
      addTearDown(index.close);
      final day = DateTime(2024, 1, 1);

      await tester.pumpWidget(
        testApp(
          index: index,
          assets: assets,
          overrides: [
            dayHeightCacheProvider.overrideWithValue({day: 123.0}),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.height == 123.0),
        findsOneWidget,
      );
    });

    testWidgets('sin altura previa usa una estimada, no cero', (tester) async {
      final assets = _oneAssetPerDay(1);
      final index = _NeverAnswersIndex(assets);
      addTearDown(index.close);

      await tester.pumpWidget(testApp(index: index, assets: assets));
      await tester.pump();
      await tester.pump();

      final reserved = find.byWidgetPredicate(
        (w) => w is SizedBox && (w.height ?? 0) > 50 && (w.height ?? 0) < 400,
      );
      expect(reserved, findsWidgets);
    });
  });
}
