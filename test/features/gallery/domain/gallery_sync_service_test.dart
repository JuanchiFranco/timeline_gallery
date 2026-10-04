import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/data/drift_sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/services/gallery_sync_service.dart';

import '../../../support/fakes.dart';
import '../../../support/fixtures.dart';

/// Cinco assets, uno por hora, `a0` el más reciente.
List<MediaAsset> _assets() => [
  for (var i = 0; i < 5; i++)
    buildAsset('a$i', captureDate: DateTime.utc(2026, 9, 1, 12 - i)),
];

void main() {
  late AppDatabase db;
  late DriftMediaIndexRepository index;
  late DriftSyncStateStore state;
  late FakeDeviceGalleryRepository device;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final logger = AppLogger(enabled: false);
    index = DriftMediaIndexRepository(db, logger);
    state = DriftSyncStateStore(db, logger);
    device = FakeDeviceGalleryRepository(_assets());
    now = DateTime.utc(2026, 9, 2);
  });

  tearDown(() => db.close());

  DefaultGallerySyncService service({DeviceGalleryRepository? override}) =>
      DefaultGallerySyncService(
        device: override ?? device,
        index: index,
        state: state,
        logger: AppLogger(enabled: false),
        clock: () => now,
        pageSize: 2,
      );

  Future<List<MediaAsset>> stored() => index.inRange(
    fromInclusive: DateTime.utc(2026),
    toExclusive: DateTime.utc(2027),
  );

  void edit(String id, {required DateTime captured, int width = 4000}) {
    final i = device.assets.indexWhere((a) => a.platformAssetId == id);
    device.assets[i] = buildAsset(
      id,
      captureDate: captured,
      modifiedDate: DateTime.utc(2026, 9, 3),
      width: width,
    );
  }

  test(
    'la primera sincronización es completa y pagina toda la galería',
    () async {
      final result = await service().sync();

      expect(result.mode, SyncMode.full);
      expect(result.added, 5);
      expect(result.removed, 0);
      expect(await index.count(), 5);
      expect(await state.read(SyncStateKey.checkpoint), '');
      expect(
        await state.read(SyncStateKey.lastFullSyncAt),
        now.toIso8601String(),
      );
    },
  );

  test('reporta el avance por página', () async {
    final progress = <(int, int)>[];

    await service().sync(onProgress: (p, t) => progress.add((p, t)));

    expect(progress, [(2, 5), (4, 5), (5, 5)]);
  });

  test('sin cambios, la incremental lee una sola página', () async {
    await service().sync();
    device.readPageCalls = 0;

    final result = await service().sync();

    expect(result.mode, SyncMode.incremental);
    expect(result.hasChanges, isFalse);
    expect(device.readPageCalls, 1);
  });

  test('la incremental agrega lo nuevo y se detiene en lo conocido', () async {
    await service().sync();
    device.assets.add(
      buildAsset('nuevo', captureDate: DateTime.utc(2026, 9, 2, 9)),
    );
    device.readPageCalls = 0;

    final result = await service().sync();

    expect(result.mode, SyncMode.incremental);
    expect(result.added, 1);
    expect(await index.count(), 6);
    // Página 0 con cambios, página 1 sin cambios: se detiene.
    expect(device.readPageCalls, 2);
  });

  test('detecta ediciones por fecha de modificación', () async {
    await service().sync();
    edit('a0', captured: DateTime.utc(2026, 9, 1, 12), width: 111);

    final result = await service().sync();

    expect(result.updated, 1);
    expect(result.added, 0);
    expect(
      (await stored()).firstWhere((a) => a.platformAssetId == 'a0').width,
      111,
    );
  });

  test('una baja hace escalar a completa y se quita del índice', () async {
    await service().sync();
    device.assets.removeWhere((a) => a.platformAssetId == 'a2');

    final result = await service().sync();

    expect(result.mode, SyncMode.full);
    expect(result.removed, 1);
    expect(await index.count(), 4);
    expect(await index.knownPlatformIds(), isNot(contains('a2')));
  });

  test('conserva isFavorite al re-sincronizar', () async {
    await service().sync();
    await (db.update(db.mediaAssets)
          ..where((t) => t.platformAssetId.equals('a1')))
        .write(const MediaAssetsCompanion(isFavorite: Value(true)));
    edit('a1', captured: DateTime.utc(2026, 9, 1, 11));

    await service().sync();

    final a1 = (await stored()).firstWhere((a) => a.platformAssetId == 'a1');
    expect(a1.isFavorite, isTrue);
  });

  test('tras una interrupción retoma desde el checkpoint', () async {
    device.failOnPage = 1;
    await expectLater(service().sync(), throwsA(isA<SyncFailure>()));

    expect(await index.count(), 2);
    expect(await state.read(SyncStateKey.checkpoint), '1');

    device
      ..failOnPage = null
      ..readPageCalls = 0;
    final result = await service().sync();

    expect(result.mode, SyncMode.full);
    expect(await index.count(), 5);
    // Páginas 1 y 2 (la 2 es corta: no hace falta pedir una vacía).
    expect(device.readPageCalls, 2);
    expect(await state.read(SyncStateKey.checkpoint), '');
  });

  test('forceFull relee todo', () async {
    await service().sync();
    device.readPageCalls = 0;

    final result = await service().sync(forceFull: true);

    expect(result.mode, SyncMode.full);
    expect(device.readPageCalls, 3);
  });

  test('pasado el intervalo de resync, la siguiente es completa', () async {
    await service().sync();
    now = now.add(const Duration(days: 8));

    final result = await service().sync();

    expect(result.mode, SyncMode.full);
  });

  test('llamadas simultáneas comparten la misma sincronización', () async {
    final sync = service();

    final first = sync.sync();
    final second = sync.sync();

    expect(identical(first, second), isTrue);
    await first;
    expect(await index.count(), 5);
  });

  test('un AppFailure de la plataforma se propaga sin envolver', () async {
    final failing = _FailingDevice(const PermissionFailure('denied'));

    await expectLater(
      service(override: failing).sync(),
      throwsA(isA<PermissionFailure>()),
    );
  });

  test('galería vacía: no hay nada que indexar ni falla', () async {
    device.assets.clear();

    final result = await service().sync();

    expect(result.scanned, 0);
    expect(await index.count(), 0);
  });
}

class _FailingDevice implements DeviceGalleryRepository {
  _FailingDevice(this.error);

  final AppFailure error;

  @override
  Future<int> totalCount() async => throw error;

  @override
  Future<List<MediaAsset>> readPage({
    required int page,
    required int pageSize,
  }) async => throw error;
}
