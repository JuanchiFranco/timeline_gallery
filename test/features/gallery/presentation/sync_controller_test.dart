import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_permission_controller.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/sync_controller.dart';

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGalleryPermissionService permissions;
  late FakeGallerySyncService sync;
  late ProviderContainer container;

  ProviderContainer build(GalleryPermission initial) {
    permissions = FakeGalleryPermissionService(initial);
    sync = FakeGallerySyncService();
    container = ProviderContainer(
      // Sin reintentos automáticos: los estados de error deben ser estables.
      retry: (retryCount, error) => null,
      overrides: [
        galleryPermissionServiceProvider.overrideWithValue(permissions),
        gallerySyncServiceProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Deja correr permiso -> microtask de arranque -> sync.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  SyncStatus status() => container.read(syncControllerProvider);

  test('sincroniza al arrancar si ya hay permiso', () async {
    build(GalleryPermission.granted);

    container.read(syncControllerProvider);
    await container.read(galleryPermissionProvider.future);
    await settle();

    expect(sync.syncCalls, 1);
    expect(status().isRunning, isFalse);
    expect(status().failure, isNull);
  });

  test('sin permiso no sincroniza', () async {
    build(GalleryPermission.denied);

    container.read(syncControllerProvider);
    await container.read(galleryPermissionProvider.future);
    await settle();

    expect(sync.syncCalls, 0);
  });

  test('sincroniza una sola vez cuando el permiso pasa a concedido', () async {
    build(GalleryPermission.notDetermined);
    container.read(syncControllerProvider);
    await container.read(galleryPermissionProvider.future);
    await settle();
    expect(sync.syncCalls, 0);

    await container.read(galleryPermissionProvider.notifier).request();
    await settle();

    expect(sync.syncCalls, 1);

    // Un refresco que no cambia el estado no vuelve a disparar la sync.
    await container.read(galleryPermissionProvider.notifier).refresh();
    await settle();
    expect(sync.syncCalls, 1);
  });

  test(
    'expone el avance mientras corre y vuelve a reposo al terminar',
    () async {
      build(GalleryPermission.granted);
      final release = Completer<void>();
      sync.script = (onProgress) async {
        onProgress?.call(5, 10);
        await release.future;
      };

      container.read(syncControllerProvider);
      await container.read(galleryPermissionProvider.future);
      await settle();

      expect(status().isRunning, isTrue);
      expect(status().processed, 5);
      expect(status().total, 10);
      expect(status().progress, 0.5);

      release.complete();
      await settle();

      expect(status().isRunning, isFalse);
      expect(status().progress, isNull);
    },
  );

  test('no solapa: pedir sync mientras corre una no inicia otra', () async {
    build(GalleryPermission.granted);
    final release = Completer<void>();
    sync.script = (_) => release.future;
    container.read(syncControllerProvider);
    await container.read(galleryPermissionProvider.future);
    await settle();
    expect(sync.syncCalls, 1);

    await container.read(syncControllerProvider.notifier).sync();
    await container.read(syncControllerProvider.notifier).sync(forceFull: true);

    expect(sync.syncCalls, 1);
    release.complete();
    await settle();
  });

  test('un fallo queda en el estado con su mensaje para el usuario', () async {
    build(GalleryPermission.granted);
    sync.error = const SyncFailure('boom');

    container.read(syncControllerProvider);
    await container.read(galleryPermissionProvider.future);
    await settle();

    expect(status().isRunning, isFalse);
    expect(status().failure, isA<SyncFailure>());
    expect(status().failure!.userMessage, isNot(contains('boom')));
  });

  test(
    'reintentar tras un fallo vuelve a sincronizar y limpia el error',
    () async {
      build(GalleryPermission.granted);
      sync.error = const SyncFailure('boom');
      container.read(syncControllerProvider);
      await container.read(galleryPermissionProvider.future);
      await settle();
      expect(status().failure, isNotNull);

      sync.error = null;
      await container.read(syncControllerProvider.notifier).sync();

      expect(sync.syncCalls, 2);
      expect(status().failure, isNull);
      expect(status().isRunning, isFalse);
    },
  );

  test(
    'un error inesperado se clasifica sin perder la sincronización',
    () async {
      build(GalleryPermission.granted);
      sync.script = (_) async => throw StateError('inesperado');

      container.read(syncControllerProvider);
      await container.read(galleryPermissionProvider.future);
      await settle();

      expect(status().failure, isA<UnexpectedFailure>());
    },
  );

  group('SyncStatus', () {
    test('igualdad por valor', () {
      expect(const SyncStatus.idle(), const SyncStatus.idle());
      expect(
        const SyncStatus.running(processed: 1, total: 2),
        const SyncStatus.running(processed: 1, total: 2),
      );
      expect(
        const SyncStatus.running(processed: 1, total: 2),
        isNot(const SyncStatus.running(processed: 2, total: 2)),
      );
    });

    test('el avance nunca pasa de 1 ni existe sin total', () {
      expect(const SyncStatus.running().progress, isNull);
      expect(const SyncStatus.running(processed: 12, total: 10).progress, 1.0);
    });
  });
}
