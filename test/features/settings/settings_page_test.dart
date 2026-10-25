import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

/// Como `testWidgets`, pero con una pantalla alta: Ajustes es una lista
/// perezosa y, en la pantalla de prueba por defecto, las secciones de abajo no
/// llegarían a construirse.
void settingsTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await body(tester);
  });
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Ajustes'));
  await tester.pumpAndSettle();
}

void main() {
  group('acceso a la galería', () {
    settingsTest('acceso completo: informa y no ofrece acciones', (
      tester,
    ) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('Acceso completo'), findsOneWidget);
      expect(find.text('Conceder acceso'), findsNothing);
      expect(find.text('Elegir más elementos'), findsNothing);
      expect(find.text('Abrir ajustes del dispositivo'), findsNothing);
    });

    settingsTest('acceso limitado: permite elegir más elementos', (
      tester,
    ) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.limited,
      );
      await tester.pumpWidget(testApp(permissions: permissions));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('Acceso limitado'), findsOneWidget);
      await tester.tap(find.text('Elegir más elementos'));
      await tester.pumpAndSettle();

      expect(permissions.manageLimitedCalls, 1);
    });

    settingsTest('rechazado: lleva a los ajustes del dispositivo', (
      tester,
    ) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.denied,
      );
      await tester.pumpWidget(testApp(permissions: permissions));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('Sin acceso'), findsOneWidget);
      await tester.tap(find.text('Abrir ajustes del dispositivo'));
      await tester.pump();

      expect(permissions.openSettingsCalls, 1);
      expect(permissions.requestCalls, 0);
    });

    settingsTest('sin decidir: pide el permiso', (tester) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.notDetermined,
      );
      await tester.pumpWidget(testApp(permissions: permissions));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      await tester.tap(find.text('Conceder acceso'));
      await tester.pumpAndSettle();

      expect(permissions.requestCalls, 1);
      expect(find.text('Acceso completo'), findsOneWidget);
    });

    settingsTest('restringido: solo informa', (tester) async {
      await tester.pumpWidget(
        testApp(
          permissions: FakeGalleryPermissionService(
            GalleryPermission.restricted,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('Acceso restringido'), findsWidgets);
      expect(find.text('Abrir ajustes del dispositivo'), findsNothing);
      expect(find.text('Conceder acceso'), findsNothing);
    });

    settingsTest('si falla leer el permiso, permite reintentar', (
      tester,
    ) async {
      final permissions = FakeGalleryPermissionService(
        GalleryPermission.granted,
      )..statusError = const PermissionFailure('boom');
      await tester.pumpWidget(testApp(permissions: permissions));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('No pudimos comprobar el acceso'), findsOneWidget);

      permissions.statusError = null;
      await tester.tap(find.text('Reintentar').last);
      await tester.pumpAndSettle();

      expect(find.text('Acceso completo'), findsOneWidget);
    });
  });

  group('sincronización', () {
    settingsTest('muestra que está al día y cuántos recuerdos hay', (
      tester,
    ) async {
      await tester.pumpWidget(testApp(assets: september(3)));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('Al día'), findsOneWidget);
      expect(find.textContaining('3 recuerdos indexados'), findsOneWidget);
    });

    settingsTest('singular cuando hay uno', (tester) async {
      await tester.pumpWidget(testApp(assets: september(1)));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.textContaining('1 recuerdo indexado'), findsOneWidget);
    });

    settingsTest('muestra cuándo fue la última sincronización', (tester) async {
      final store = FakeSyncStateStore();
      store.values[SyncStateKey.lastIncrementalSyncAt] = DateTime.now()
          .toUtc()
          .toIso8601String();

      await tester.pumpWidget(testApp(syncState: store));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.textContaining('Última vez: Hoy'), findsOneWidget);
    });

    settingsTest('sin sincronizaciones previas no inventa una fecha', (
      tester,
    ) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.textContaining('Última vez'), findsNothing);
    });

    settingsTest('"Volver a escanear" pide un re-escaneo completo', (
      tester,
    ) async {
      final sync = FakeGallerySyncService();
      await tester.pumpWidget(testApp(sync: sync));
      await tester.pumpAndSettle();
      await _openSettings(tester);
      final before = sync.syncCalls;

      await tester.tap(find.text('Volver a escanear la galería'));
      await tester.pumpAndSettle();

      expect(sync.syncCalls, before + 1);
      expect(sync.forceFullCalls, 1);
    });

    settingsTest('sin permiso de lectura no se puede escanear', (tester) async {
      await tester.pumpWidget(
        testApp(
          permissions: FakeGalleryPermissionService(GalleryPermission.denied),
        ),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Volver a escanear la galería'),
      );
      expect(button.onPressed, isNull);
    });

    settingsTest('mientras sincroniza muestra el avance y bloquea el botón', (
      tester,
    ) async {
      final sync = FakeGallerySyncService();
      final release = Completer<void>();
      sync.script = (onProgress) async {
        onProgress?.call(5, 10);
        await release.future;
      };
      await tester.pumpWidget(testApp(sync: sync));
      await tester.pump();
      await tester.pump();
      await _openSettingsKeepingFrames(tester);

      expect(find.text('Sincronizando…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Volver a escanear la galería'),
      );
      expect(button.onPressed, isNull);

      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Al día'), findsOneWidget);
    });

    settingsTest('un fallo se muestra con su mensaje para el usuario', (
      tester,
    ) async {
      final sync = FakeGallerySyncService(error: const SyncFailure('boom'));
      await tester.pumpWidget(testApp(sync: sync));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text(const SyncFailure('x').userMessage), findsWidgets);
      expect(find.textContaining('boom'), findsNothing);
    });
  });

  group('privacidad y acerca de', () {
    settingsTest('explica que es local y qué se guarda', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('100% local'), findsOneWidget);
      expect(find.textContaining('no se conecta a Internet'), findsOneWidget);
      expect(find.text('Qué guarda la app'), findsOneWidget);
    });

    settingsTest('muestra el nombre y la versión', (tester) async {
      await tester.pumpWidget(
        testApp(
          packageInfo: PackageInfo(
            appName: 'x',
            packageName: 'x',
            version: '2.3.4',
            buildNumber: '17',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(find.text('Galería de eventos'), findsOneWidget);
      expect(find.text('Versión 2.3.4 (17)'), findsOneWidget);
    });

    settingsTest('abre la pantalla de licencias', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      await _openSettings(tester);

      await tester.tap(find.text('Licencias de código abierto'));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}

/// Abre Ajustes sin esperar a que no haya frames pendientes (la barra de
/// progreso de una sincronización en curso anima sin parar).
Future<void> _openSettingsKeepingFrames(WidgetTester tester) async {
  await tester.tap(find.text('Ajustes'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
