import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_platform.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../../support/test_app.dart';

/// `september(3)`, del más reciente al más antiguo en el visor:
/// p2 (08:10, foto), p1 (08:05, foto), p0 (08:00, video).
Widget _app({FakeMediaFileRepository? mediaFiles}) => testApp(
  months: septemberBuckets(3),
  assets: september(3),
  mediaFiles: mediaFiles,
);

Future<void> _open(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
}

/// Un toque simple se confirma cuando vence la ventana del doble toque.
Future<void> _singleTap(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 300));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

double _chromeOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

void main() {
  late FakeVideoPlayerPlatform video;

  setUp(() {
    video = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = video;
  });

  group('Abrir el visor', () {
    testWidgets('tocar una miniatura del timeline abre ese asset', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Orden de la grilla: p2, p1, p0. La segunda es p1.
      await tester.tap(find.byType(ThumbnailTile).at(1));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.textContaining('23 de septiembre'), findsOneWidget);
      expect(find.text('08:05'), findsOneWidget);
    });

    testWidgets('volver regresa al timeline', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ThumbnailTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('Septiembre · 3'), findsOneWidget);
      expect(find.text('1 / 3'), findsNothing);
    });

    testWidgets('el visor ocupa toda la pantalla, sin barra inferior', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      await _open(tester, '/viewer/2026-09-23/p1');

      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('un id que ya no existe abre el primer asset del día', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _open(tester, '/viewer/2026-09-23/borrado');

      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('un día sin assets lo indica y permite volver', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _open(tester, '/viewer/2026-01-01/p1');

      expect(find.text('Este recuerdo ya no está'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
    });

    testWidgets('una fecha inválida muestra un aviso', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _open(tester, '/viewer/2026-02-31/p1');

      expect(find.text('Esa fecha no es válida'), findsOneWidget);
    });

    testWidgets('un enlace directo sin historial vuelve al inicio', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester, '/viewer/2026-09-23/p1');

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('Tus recuerdos'), findsOneWidget);
    });

    testWidgets('los assets sin fecha se abren desde "sin-fecha"', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          months: Stream.value(const [MonthBucket(MonthKey.undated(), 1)]),
          assets: [
            buildAsset(
              'u1',
              captureDate: DateTime.utc(1970),
              source: CaptureDateSource.unknown,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ThumbnailTile));
      await tester.pumpAndSettle();

      expect(find.text('Fecha desconocida'), findsNWidgets(1));
      expect(find.text('1 / 1'), findsOneWidget);
    });
  });

  group('Navegar entre assets', () {
    testWidgets('deslizar cambia de asset y actualiza el contador', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester, '/viewer/2026-09-23/p2');
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('08:10'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('08:05'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('tocar la imagen oculta y vuelve a mostrar la barra', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester, '/viewer/2026-09-23/p2');
      expect(_chromeOpacity(tester), 1);

      await _singleTap(tester);
      expect(_chromeOpacity(tester), 0);

      await _singleTap(tester);
      expect(_chromeOpacity(tester), 1);
    });

    testWidgets('con zoom no se cambia de asset al arrastrar', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester, '/viewer/2026-09-23/p2');

      // Doble toque: zoom.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      final pager = tester.widget<PageView>(find.byType(PageView));
      expect(pager.physics, isA<NeverScrollableScrollPhysics>());

      // Otro doble toque: vuelve a 1x y se puede deslizar.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      final restored = tester.widget<PageView>(find.byType(PageView));
      expect(restored.physics, isA<PageScrollPhysics>());
    });

    testWidgets('si la foto no carga muestra un aviso', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _open(tester, '/viewer/2026-09-23/p2');

      expect(find.text('No se pudo cargar la foto'), findsOneWidget);
    });
  });

  group('Video', () {
    Future<void> openVideo(WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester, '/viewer/2026-09-23/p0');
    }

    testWidgets('empieza con póster y no abre el reproductor hasta tocar', (
      tester,
    ) async {
      await openVideo(tester);

      expect(find.byTooltip('Reproducir'), findsOneWidget);
      expect(video.openedUris, isEmpty);
    });

    testWidgets('reproducir abre el archivo y muestra los controles', (
      tester,
    ) async {
      await openVideo(tester);

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      expect(video.openedUris.single, endsWith('/fake/video.mp4'));
      expect(video.playing, isNotEmpty);
      expect(find.byTooltip('Pausar'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('0:00 / 0:12'), findsOneWidget);
    });

    testWidgets('los controles quedan abajo, no en medio de la pantalla', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      await openVideo(tester);

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      // Un Slider se expande a la altura que le den: debe ser solo la barra.
      final slider = tester.getRect(find.byType(Slider));
      expect(slider.height, lessThanOrEqualTo(64));
      expect(slider.bottom, greaterThan(700));
    });

    testWidgets('pausar y reanudar', (tester) async {
      await openVideo(tester);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pausar'));
      await tester.pumpAndSettle();
      expect(video.playing, isEmpty);
      expect(find.byTooltip('Reproducir'), findsOneWidget);

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(video.playing, isNotEmpty);
    });

    testWidgets('al salir del video se libera el reproductor', (tester) async {
      await openVideo(tester);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(video.playing, isNotEmpty);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      // `VideoPlayerController.dispose` es asíncrono y termina en el event loop
      // real, fuera del reloj simulado de los tests de widgets.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(video.playing, isEmpty);
    });

    testWidgets('si el archivo ya no existe avisa y deja reintentar', (
      tester,
    ) async {
      await tester.pumpWidget(_app(mediaFiles: FakeMediaFileRepository(null)));
      await tester.pumpAndSettle();
      await _open(tester, '/viewer/2026-09-23/p0');

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo reproducir el video'), findsOneWidget);
      expect(find.byTooltip('Reproducir'), findsOneWidget);
    });

    testWidgets('si el reproductor falla avisa sin romper el visor', (
      tester,
    ) async {
      video.failToCreate = true;
      await openVideo(tester);

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo reproducir el video'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
    });
  });
}
