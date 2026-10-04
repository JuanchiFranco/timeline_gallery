import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/app/app.dart';
import 'package:galeria_eventos/app/theme/app_theme.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';

/// [count] assets el 23 de septiembre de 2026 (hora local), uno cada 5 minutos
/// desde las 08:00, así que forman un solo momento.
List<MediaAsset> _september(int count) => [
  for (var i = 0; i < count; i++)
    buildAsset(
      'p$i',
      captureDate: DateTime(2026, 9, 23, 8, i * 5).toUtc(),
      type: i == 0 ? MediaType.video : MediaType.image,
    ),
];

Stream<List<MonthBucket>> _septemberBuckets(int count) =>
    Stream.value([MonthBucket(const MonthKey(2026, 9), count)]);

Widget _app({
  required Stream<List<MonthBucket>> months,
  List<MediaAsset> assets = const [],
  FakeGalleryPermissionService? permissions,
  FakeGallerySyncService? sync,
}) {
  return ProviderScope(
    // Sin reintentos automáticos: los tests de error deben ser deterministas.
    retry: (retryCount, error) => null,
    overrides: [
      monthBucketsProvider.overrideWith((ref) => months),
      mediaIndexRepositoryProvider.overrideWithValue(
        FakeMediaIndexRepository(assets),
      ),
      thumbnailRepositoryProvider.overrideWithValue(FakeThumbnailRepository()),
      galleryPermissionServiceProvider.overrideWithValue(
        permissions ?? FakeGalleryPermissionService(GalleryPermission.granted),
      ),
      gallerySyncServiceProvider.overrideWithValue(
        sync ?? FakeGallerySyncService(),
      ),
    ],
    child: const GaleriaApp(),
  );
}

void main() {
  group('Permiso de galería', () {
    testWidgets('sin decidir ofrece pedir acceso y luego muestra el timeline', (
      tester,
    ) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.notDetermined,
      );

      await tester.pumpWidget(
        _app(months: Stream.value(const []), permissions: permissions),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tus recuerdos, en una línea de tiempo'),
        findsOneWidget,
      );
      expect(find.text('Aún no hay recuerdos para mostrar'), findsNothing);

      await tester.tap(find.text('Conceder acceso'));
      await tester.pumpAndSettle();

      expect(permissions.requestCalls, 1);
      expect(find.text('Aún no hay recuerdos para mostrar'), findsOneWidget);
    });

    testWidgets('rechazado lleva a los ajustes del sistema', (tester) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.denied,
      );

      await tester.pumpWidget(
        _app(months: Stream.value(const []), permissions: permissions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin acceso a tu galería'), findsOneWidget);
      expect(find.text('Conceder acceso'), findsNothing);

      await tester.tap(find.text('Abrir ajustes'));
      await tester.pump();

      expect(permissions.openSettingsCalls, 1);
      expect(permissions.requestCalls, 0);
    });

    testWidgets('restringido solo informa, sin acciones', (tester) async {
      await tester.pumpWidget(
        _app(
          months: Stream.value(const []),
          permissions: FakeGalleryPermissionService(
            GalleryPermission.restricted,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('acceso limitado muestra el aviso y permite ampliarlo', (
      tester,
    ) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.limited,
      );

      await tester.pumpWidget(
        _app(
          months: _septemberBuckets(3),
          assets: _september(3),
          permissions: permissions,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Septiembre · 3'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);

      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();

      expect(permissions.manageLimitedCalls, 1);
    });

    testWidgets('acceso completo no muestra el aviso de limitado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(months: _septemberBuckets(3), assets: _september(3)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsNothing);
    });
  });

  group('Sincronización', () {
    testWidgets('al tener permiso sincroniza una vez', (tester) async {
      final sync = FakeGallerySyncService();

      await tester.pumpWidget(_app(months: Stream.value(const []), sync: sync));
      await tester.pumpAndSettle();

      expect(sync.syncCalls, 1);
    });

    testWidgets('sin permiso no sincroniza; al concederlo sí', (tester) async {
      final sync = FakeGallerySyncService();
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.notDetermined,
      );

      await tester.pumpWidget(
        _app(
          months: Stream.value(const []),
          permissions: permissions,
          sync: sync,
        ),
      );
      await tester.pumpAndSettle();
      expect(sync.syncCalls, 0);

      await tester.tap(find.text('Conceder acceso'));
      await tester.pumpAndSettle();

      expect(sync.syncCalls, 1);
    });

    testWidgets('si falla muestra el aviso y permite reintentar', (
      tester,
    ) async {
      final sync = FakeGallerySyncService(error: const SyncFailure('boom'));

      await tester.pumpWidget(_app(months: Stream.value(const []), sync: sync));
      await tester.pumpAndSettle();

      expect(find.text(const SyncFailure('x').userMessage), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);

      sync.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(sync.syncCalls, 2);
      expect(find.text(const SyncFailure('x').userMessage), findsNothing);
    });
  });

  group('Timeline (estados base)', () {
    testWidgets('sin recuerdos muestra el estado vacío', (tester) async {
      await tester.pumpWidget(_app(months: Stream.value(const [])));
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay recuerdos para mostrar'), findsOneWidget);
    });

    testWidgets('mientras carga muestra un indicador de progreso', (
      tester,
    ) async {
      final controller = StreamController<List<MonthBucket>>();
      addTearDown(controller.close);

      await tester.pumpWidget(_app(months: controller.stream));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ante un fallo muestra el mensaje para el usuario', (
      tester,
    ) async {
      const failure = StorageFailure('boom');

      await tester.pumpWidget(
        _app(months: Stream<List<MonthBucket>>.error(failure)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Algo salió mal'), findsOneWidget);
      expect(find.text(failure.userMessage), findsOneWidget);
      // Nunca se expone el mensaje técnico.
      expect(find.textContaining('boom'), findsNothing);
    });
  });

  group('Timeline (contenido)', () {
    testWidgets('muestra año, mes, día y momento', (tester) async {
      await tester.pumpWidget(
        _app(months: _septemberBuckets(3), assets: _september(3)),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Septiembre · 3'), findsOneWidget);
      expect(find.textContaining('23 de septiembre'), findsOneWidget);
      // 08:00, 08:05 y 08:10: un video y dos fotos.
      expect(find.text('08:00 – 08:10 · 2 fotos, 1 video'), findsOneWidget);
      expect(find.byType(ThumbnailTile), findsNWidgets(3));
    });

    testWidgets('un momento grande resume el resto como +N', (tester) async {
      await tester.pumpWidget(
        _app(months: _septemberBuckets(10), assets: _september(10)),
      );
      await tester.pumpAndSettle();

      // 8 celdas: 7 miniaturas y la última con el resto (10 - 7 = 3).
      expect(find.byType(ThumbnailTile), findsNWidgets(8));
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('el año se muestra una vez por grupo de meses', (tester) async {
      // Pantalla alta: la lista es perezosa y así construye los tres meses.
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 3000);
      addTearDown(tester.view.reset);

      final assets = [
        ..._september(1),
        buildAsset('oct', captureDate: DateTime(2026, 10, 2, 9).toUtc()),
        buildAsset('dic', captureDate: DateTime(2025, 12, 5, 9).toUtc()),
      ];

      await tester.pumpWidget(
        _app(
          months: Stream.value(const [
            MonthBucket(MonthKey(2026, 10), 1),
            MonthBucket(MonthKey(2026, 9), 1),
            MonthBucket(MonthKey(2025, 12), 1),
          ]),
          assets: assets,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Octubre · 1'), findsOneWidget);
      expect(find.text('Septiembre · 1'), findsOneWidget);

      expect(find.text('2025'), findsOneWidget);
      expect(find.text('Diciembre · 1'), findsOneWidget);
    });

    testWidgets('los assets sin fecha van bajo "Sin fecha"', (tester) async {
      await tester.pumpWidget(
        _app(
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

      expect(find.text('Sin fecha · 1'), findsOneWidget);
      expect(find.text('Fecha desconocida'), findsOneWidget);
      // Sin fecha no hay hora que mostrar.
      expect(find.text('1 foto'), findsOneWidget);
    });
  });

  group('Navegación', () {
    testWidgets('la barra inferior cambia entre las tres secciones', (
      tester,
    ) async {
      await tester.pumpWidget(_app(months: Stream.value(const [])));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.text('Tu calendario de recuerdos'), findsOneWidget);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('100% local'), findsOneWidget);

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.text('Tus recuerdos'), findsOneWidget);
    });
  });

  group('Tema', () {
    test('claro y oscuro usan Material 3 con su brillo correspondiente', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });
  });
}
