import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

import '../../../support/fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftMediaIndexRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftMediaIndexRepository(db, AppLogger(enabled: false));
  });

  tearDown(() => db.close());

  group('upsertAll', () {
    test('inserta assets nuevos', () async {
      await repository.upsertAll([buildAsset('a'), buildAsset('b')]);

      expect(await repository.count(), 2);
    });

    test('no duplica: el mismo platformAssetId se actualiza', () async {
      await repository.upsertAll([buildAsset('a', width: 100)]);
      await repository.upsertAll([buildAsset('a', width: 200)]);

      final all = await repository.inRange(
        fromInclusive: DateTime.utc(2000),
        toExclusive: DateTime.utc(2100),
      );
      expect(all, hasLength(1));
      expect(all.single.width, 200);
    });

    test('al actualizar conserva isFavorite, que es estado local', () async {
      await repository.upsertAll([buildAsset('a')]);
      await (db.update(db.mediaAssets)
            ..where((t) => t.platformAssetId.equals('a')))
          .write(const MediaAssetsCompanion(isFavorite: Value(true)));

      // La plataforma re-entrega el asset (por ejemplo, tras editarlo).
      await repository.upsertAll([buildAsset('a', width: 999)]);

      final stored = (await repository.inRange(
        fromInclusive: DateTime.utc(2000),
        toExclusive: DateTime.utc(2100),
      )).single;
      expect(stored.width, 999);
      expect(stored.isFavorite, isTrue);
    });

    test('una lista vacía no hace nada', () async {
      await repository.upsertAll(const []);

      expect(await repository.count(), 0);
    });

    test('conserva los datos de un video', () async {
      final video = buildAsset('v', type: MediaType.video);

      await repository.upsertAll([video]);

      final stored = (await repository.inRange(
        fromInclusive: DateTime.utc(2000),
        toExclusive: DateTime.utc(2100),
      )).single;
      expect(stored, video);
      expect(stored.duration, const Duration(seconds: 12));
    });
  });

  group('deleteByPlatformIds', () {
    test('elimina solo los ids indicados y devuelve cuántos', () async {
      await repository.upsertAll([
        buildAsset('a'),
        buildAsset('b'),
        buildAsset('c'),
      ]);

      final deleted = await repository.deleteByPlatformIds(['a', 'c', 'zzz']);

      expect(deleted, 2);
      expect(await repository.knownPlatformIds(), {'b'});
    });

    test('procesa listas más grandes que un lote', () async {
      final assets = [for (var i = 0; i < 1200; i++) buildAsset('id$i')];
      await repository.upsertAll(assets);

      final deleted = await repository.deleteByPlatformIds([
        for (var i = 0; i < 1100; i++) 'id$i',
      ]);

      expect(deleted, 1100);
      expect(await repository.count(), 100);
    });
  });

  group('inRange', () {
    test('incluye el inicio, excluye el fin y ordena del más nuevo al más '
        'antiguo', () async {
      final t0 = DateTime.utc(2026, 9, 23, 10);
      await repository.upsertAll([
        buildAsset(
          'antes',
          captureDate: t0.subtract(const Duration(seconds: 1)),
        ),
        buildAsset('inicio', captureDate: t0),
        buildAsset('medio', captureDate: t0.add(const Duration(hours: 1))),
        buildAsset('fin', captureDate: t0.add(const Duration(hours: 2))),
      ]);

      final result = await repository.inRange(
        fromInclusive: t0,
        toExclusive: t0.add(const Duration(hours: 2)),
      );

      expect(result.map((a) => a.platformAssetId), ['medio', 'inicio']);
    });

    test(
      'desempata por orden de inserción cuando coincide el segundo',
      () async {
        final sameSecond = DateTime.utc(2026, 9, 23, 10);
        await repository.upsertAll([
          buildAsset('primero', captureDate: sameSecond),
          buildAsset('segundo', captureDate: sameSecond),
        ]);

        final result = await repository.inRange(
          fromInclusive: sameSecond,
          toExclusive: sameSecond.add(const Duration(seconds: 1)),
        );

        expect(result.map((a) => a.platformAssetId), ['segundo', 'primero']);
      },
    );

    test('devuelve fechas en UTC', () async {
      await repository.upsertAll([buildAsset('a')]);

      final stored = (await repository.inRange(
        fromInclusive: DateTime.utc(2000),
        toExclusive: DateTime.utc(2100),
      )).single;

      expect(stored.captureDate.isUtc, isTrue);
      expect(stored.captureDate, DateTime.utc(2026, 9, 23, 8, 32));
    });
  });

  group('streams', () {
    test('watchCount emite cuando cambia el índice', () async {
      final values = <int>[];
      final subscription = repository.watchCount().listen(values.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.upsertAll([buildAsset('a'), buildAsset('b')]);
      await pumpEventQueue();
      await repository.deleteByPlatformIds(['a']);
      await pumpEventQueue();

      expect(values, [0, 2, 1]);
    });
  });

  group('errores', () {
    test('una base cerrada se traduce a StorageFailure', () async {
      final closed = AppDatabase(NativeDatabase.memory());
      final closedRepository = DriftMediaIndexRepository(
        closed,
        AppLogger(enabled: false),
      );
      await closedRepository
          .count(); // drift abre la conexión de forma perezosa
      await closed.close();

      await expectLater(
        closedRepository.upsertAll([buildAsset('a')]),
        throwsA(isA<StorageFailure>()),
      );
      await expectLater(
        closedRepository.count(),
        throwsA(isA<StorageFailure>()),
      );
    });

    test('un código de tipo corrupto se traduce a StorageFailure', () async {
      await db
          .into(db.mediaAssets)
          .insert(
            MediaAssetsCompanion.insert(
              platformAssetId: 'corrupto',
              type: 99,
              captureDate: DateTime.utc(2026, 9, 23),
              captureDateSource: 0,
              modifiedDate: DateTime.utc(2026, 9, 23),
              width: 1,
              height: 1,
              mimeType: 'image/jpeg',
            ),
          );

      await expectLater(
        repository.inRange(
          fromInclusive: DateTime.utc(2000),
          toExclusive: DateTime.utc(2100),
        ),
        throwsA(isA<StorageFailure>()),
      );
    });
  });
}
