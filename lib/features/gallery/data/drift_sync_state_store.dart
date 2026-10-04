import 'package:drift/drift.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';

/// Persiste el progreso de sincronización en la misma base del índice, de
/// modo que el checkpoint y los assets se confirman con la misma durabilidad.
class DriftSyncStateStore implements SyncStateStore {
  DriftSyncStateStore(this._db, this._logger);

  final AppDatabase _db;
  final AppLogger _logger;

  @override
  Future<String?> read(SyncStateKey key) => _guard('read', () async {
    final row = await (_db.select(
      _db.syncStateEntries,
    )..where((t) => t.key.equals(key.name))).getSingleOrNull();
    return row?.value;
  });

  @override
  Future<void> write(SyncStateKey key, String value) =>
      _guard('write', () async {
        await _db
            .into(_db.syncStateEntries)
            .insertOnConflictUpdate(
              SyncStateEntriesCompanion.insert(
                key: key.name,
                value: value,
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
      });

  @override
  Future<void> clear() => _guard('clear', () async {
    await _db.delete(_db.syncStateEntries).go();
  });

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.database,
        'syncState.$operation failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw StorageFailure(
        'syncState.$operation failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
