@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';

import '../support/test_app.dart';
import 'perf_data.dart';

/// Mide cuánto cuesta construir el timeline con datos reales de gran tamaño.
/// Los tiempos son de `flutter_tester` en esta máquina (sin GPU ni la
/// velocidad de un teléfono): sirven para comparar, no como valor absoluto.
///
///   flutter test --run-skipped --tags perf test/perf/ui_perf_test.dart
void main() {
  late SyntheticGallery gallery;

  setUpAll(() => gallery = SyntheticGallery());

  void log(String label, Object value) =>
      // ignore: avoid_print
      print('PERF ${label.padRight(44)} $value');

  testWidgets('línea base: arrancar la app sin recuerdos', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);

    final watch = Stopwatch()..start();
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    log('línea base (app vacía)', '${watch.elapsedMilliseconds} ms');
  });

  testWidgets('el mes pesado, solo', (tester) async {
    final heavy = MonthKey(gallery.heavyMonth.year, gallery.heavyMonth.month);
    final assets = [
      for (final a in gallery.assets)
        if (!a.captureDate.isBefore(heavy.startUtc) &&
            a.captureDate.isBefore(heavy.endUtc))
          a,
    ];
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);

    final watch = Stopwatch()..start();
    await tester.pumpWidget(testApp(assets: assets));
    await tester.pumpAndSettle();
    watch.stop();

    log(
      'mes pesado (${assets.length} assets): primer frame listo',
      '${watch.elapsedMilliseconds} ms',
    );
    log(
      '  ThumbnailTile construidas',
      find.byType(ThumbnailTile, skipOffstage: false).evaluate().length,
    );
  });

  testWidgets('toda la galería: abrir y recorrer el timeline', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);

    final open = Stopwatch()..start();
    await tester.pumpWidget(
      testApp(assets: gallery.assets, index: PresortedIndex(gallery.assets)),
    );
    await tester.pumpAndSettle();
    open.stop();
    log('abrir (galería completa)', '${open.elapsedMilliseconds} ms');
    log(
      '  ThumbnailTile construidas',
      find.byType(ThumbnailTile, skipOffstage: false).evaluate().length,
    );

    // Recorre 40 pantallas hacia abajo, midiendo el costo de cada paso.
    final steps = <int>[];
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      final step = Stopwatch()..start();
      await tester.drag(list, const Offset(0, -1800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      step.stop();
      steps.add(step.elapsedMilliseconds);
    }
    steps.sort();
    log('scroll: mediana por paso', '${steps[steps.length ~/ 2]} ms');
    log('scroll: p95 por paso', '${steps[(steps.length * 95) ~/ 100]} ms');
    log('scroll: peor paso', '${steps.last} ms');
  });
}
