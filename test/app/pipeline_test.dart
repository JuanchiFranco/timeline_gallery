import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/app/app.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/di/core_providers.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/sync_controller.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';

/// Recorre la tubería completa con las implementaciones reales de dominio y
/// datos (servicio de sync, repositorios Drift, providers, pantallas); solo la
/// plataforma (galería, permiso, miniaturas) es simulada.
void main() {
  late AppDatabase db;
  late FakeDeviceGalleryRepository device;
  late FakeGalleryPermissionService permissions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    device = FakeDeviceGalleryRepository();
    permissions = FakeGalleryPermissionService(GalleryPermission.granted);
  });

  Widget app() => ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appLoggerProvider.overrideWithValue(AppLogger(enabled: false)),
      deviceGalleryRepositoryProvider.overrideWithValue(device),
      galleryPermissionServiceProvider.overrideWithValue(permissions),
      thumbnailRepositoryProvider.overrideWithValue(FakeThumbnailRepository()),
    ],
    child: const GaleriaApp(),
  );

  /// La base real usa el event loop real; el reloj simulado de los tests de
  /// widgets no lo avanza solo.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Desmonta la app (cancela las consultas reactivas de Drift) y cierra la
  /// base con el event loop real. Cerrarla desde `tearDown`, bajo el reloj
  /// simulado, se queda esperando para siempre.
  Future<void> shutdown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(db.close);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('de la galería del dispositivo a la pantalla', (tester) async {
    device.assets.addAll([
      buildAsset('a', captureDate: DateTime(2026, 9, 23, 8).toUtc()),
      buildAsset('b', captureDate: DateTime(2026, 9, 23, 8, 5).toUtc()),
      buildAsset('c', captureDate: DateTime(2026, 8, 2, 12).toUtc()),
    ]);

    await tester.pumpWidget(app());
    await settle(tester);

    // Los dos meses, con su conteo, salidos del índice real.
    expect(find.text('Septiembre · 2'), findsOneWidget);
    expect(find.text('Agosto · 1'), findsOneWidget);
    expect(find.byType(ThumbnailTile), findsNWidgets(3));

    await shutdown(tester);
  });

  testWidgets('una galería vacía no rompe y muestra el estado vacío', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Aún no hay recuerdos para mostrar'), findsOneWidget);

    await shutdown(tester);
  });

  testWidgets('una foto nueva aparece al sincronizar de nuevo', (tester) async {
    device.assets.add(
      buildAsset('a', captureDate: DateTime(2026, 9, 23, 8).toUtc()),
    );
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(ThumbnailTile), findsOneWidget);

    device.assets.add(
      buildAsset('nueva', captureDate: DateTime(2026, 9, 23, 9).toUtc()),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GaleriaApp)),
    );
    unawaited(container.read(syncControllerProvider.notifier).sync());
    await settle(tester);

    expect(find.text('Septiembre · 2'), findsOneWidget);
    expect(find.byType(ThumbnailTile), findsNWidgets(2));

    await shutdown(tester);
  });

  testWidgets('una foto borrada del dispositivo desaparece del timeline', (
    tester,
  ) async {
    device.assets.addAll([
      buildAsset('a', captureDate: DateTime(2026, 9, 23, 8).toUtc()),
      buildAsset('b', captureDate: DateTime(2026, 8, 2, 12).toUtc()),
    ]);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Agosto · 1'), findsOneWidget);

    device.assets.removeWhere((a) => a.platformAssetId == 'b');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GaleriaApp)),
    );
    unawaited(container.read(syncControllerProvider.notifier).sync());
    await settle(tester);

    expect(find.text('Agosto · 1'), findsNothing);
    expect(find.text('Septiembre · 1'), findsOneWidget);

    await shutdown(tester);
  });

  testWidgets('tocar una miniatura abre el visor con esa foto', (tester) async {
    device.assets.addAll([
      buildAsset('a', captureDate: DateTime(2026, 9, 23, 8).toUtc()),
      buildAsset('b', captureDate: DateTime(2026, 9, 23, 9).toUtc()),
    ]);
    await tester.pumpWidget(app());
    await settle(tester);

    // Orden de la grilla: b (más reciente), a. La segunda celda es 'a'.
    await tester.tap(find.byType(ThumbnailTile).at(1));
    await settle(tester);

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);

    await shutdown(tester);
  });
}
