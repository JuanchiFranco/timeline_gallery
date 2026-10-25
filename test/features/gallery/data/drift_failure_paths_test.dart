import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/data/drift_sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';

import '../../../support/fixtures.dart';

/// Con la base dañada (aquí: sin sus tablas) toda operación falla en SQLite: el
/// límite de la capa de datos debe traducirlo a `StorageFailure`, sin filtrar el
/// error original a la UI. (Una base *cerrada* no sirve para simularlo: Drift
/// la reabre sola.)
void main() {
  late AppDatabase db;
  late DriftMediaIndexRepository index;
  late DriftSyncStateStore state;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final logger = AppLogger(enabled: false);
    index = DriftMediaIndexRepository(db, logger);
    state = DriftSyncStateStore(db, logger);
    await db.customStatement('DROP TABLE media_assets');
    await db.customStatement('DROP TABLE sync_state_entries');
  });

  tearDown(() => db.close());

  final range = (from: DateTime.utc(2000), to: DateTime.utc(2100));

  group('índice con la base dañada', () {
    test('las operaciones de escritura fallan con StorageFailure', () {
      expect(
        index.upsertAll([buildAsset('a')]),
        throwsA(isA<StorageFailure>()),
      );
      expect(index.deleteByPlatformIds(['a']), throwsA(isA<StorageFailure>()));
    });

    test('las lecturas fallan con StorageFailure', () {
      expect(index.knownPlatformIds(), throwsA(isA<StorageFailure>()));
      expect(index.modifiedDatesOf(['a']), throwsA(isA<StorageFailure>()));
      expect(index.count(), throwsA(isA<StorageFailure>()));
      expect(
        index.inRange(fromInclusive: range.from, toExclusive: range.to),
        throwsA(isA<StorageFailure>()),
      );
    });

    test('los streams emiten StorageFailure en vez de un error crudo', () {
      expect(index.watchCount(), emitsError(isA<StorageFailure>()));
      expect(index.watchDayBuckets(), emitsError(isA<StorageFailure>()));
      expect(
        index.watchRange(fromInclusive: range.from, toExclusive: range.to),
        emitsError(isA<StorageFailure>()),
      );
    });

    test('el mensaje para el usuario no incluye el error de SQLite', () async {
      try {
        await index.count();
        fail('debía fallar');
      } on StorageFailure catch (failure) {
        expect(failure.userMessage, isNot(contains('no such table')));
        expect(failure.userMessage, isNot(contains('SQL')));
        expect(failure.cause, isNotNull, reason: 'se conserva para depurar');
      }
    });

    test('una lista vacía no toca la base', () async {
      expect(await index.deleteByPlatformIds(const []), 0);
      await index.upsertAll(const []);
    });
  });

  group('estado de sync con la base dañada', () {
    test('read, write y clear fallan con StorageFailure', () {
      expect(
        state.read(SyncStateKey.checkpoint),
        throwsA(isA<StorageFailure>()),
      );
      expect(
        state.write(SyncStateKey.checkpoint, '1'),
        throwsA(isA<StorageFailure>()),
      );
      expect(state.clear(), throwsA(isA<StorageFailure>()));
    });
  });
}
