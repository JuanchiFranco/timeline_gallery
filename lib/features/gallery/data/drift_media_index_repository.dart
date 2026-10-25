import 'dart:async';

import 'package:drift/drift.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_index_repository.dart';

/// Implementación del índice sobre Drift/SQLite.
class DriftMediaIndexRepository implements MediaIndexRepository {
  DriftMediaIndexRepository(this._db, this._logger);

  final AppDatabase _db;
  final AppLogger _logger;

  /// Margen bajo el límite de variables de SQLite para `IN (...)`.
  static const _deleteChunkSize = 500;

  @override
  Future<void> upsertAll(List<MediaAsset> assets) =>
      _guard('upsertAll', () async {
        if (assets.isEmpty) return;
        final table = _db.mediaAssets;
        final now = DateTime.now().toUtc();

        await _db.batch((batch) {
          for (final asset in assets) {
            batch.insert(
              table,
              _toInsertCompanion(asset),
              // Al actualizar solo se tocan los campos que vienen de la
              // plataforma; `isFavorite` y `createdAt` son estado local.
              onConflict: DoUpdate<$MediaAssetsTable, MediaAssetRow>(
                (_) => _toPlatformUpdateCompanion(asset, now),
                target: [table.platformAssetId],
              ),
            );
          }
        });
      });

  @override
  Future<int> deleteByPlatformIds(Iterable<String> platformAssetIds) =>
      _guard('deleteByPlatformIds', () async {
        final ids = platformAssetIds.toList();
        if (ids.isEmpty) return 0;
        return _db.transaction(() async {
          var deleted = 0;
          for (var start = 0; start < ids.length; start += _deleteChunkSize) {
            final end = start + _deleteChunkSize < ids.length
                ? start + _deleteChunkSize
                : ids.length;
            final chunk = ids.sublist(start, end);
            deleted += await (_db.delete(
              _db.mediaAssets,
            )..where((t) => t.platformAssetId.isIn(chunk))).go();
          }
          return deleted;
        });
      });

  @override
  Future<Set<String>> knownPlatformIds() =>
      _guard('knownPlatformIds', () async {
        final column = _db.mediaAssets.platformAssetId;
        final query = _db.selectOnly(_db.mediaAssets)..addColumns([column]);
        final ids = await query.map((row) => row.read(column)!).get();
        return ids.toSet();
      });

  @override
  Future<Map<String, DateTime>> modifiedDatesOf(
    Iterable<String> platformAssetIds,
  ) => _guard('modifiedDatesOf', () async {
    final ids = platformAssetIds.toList();
    final table = _db.mediaAssets;
    final result = <String, DateTime>{};
    // Por lotes: SQLite limita las variables de un `IN (...)`.
    for (var start = 0; start < ids.length; start += _deleteChunkSize) {
      final end = start + _deleteChunkSize < ids.length
          ? start + _deleteChunkSize
          : ids.length;
      final query = _db.selectOnly(table)
        ..addColumns([table.platformAssetId, table.modifiedDate])
        ..where(table.platformAssetId.isIn(ids.sublist(start, end)));
      for (final row in await query.get()) {
        result[row.read(table.platformAssetId)!] = row
            .read(table.modifiedDate)!
            .toUtc();
      }
    }
    return result;
  });

  @override
  Future<int> count() => _guard('count', _countQuery().getSingle);

  @override
  Stream<int> watchCount() =>
      _guardStream('watchCount', _countQuery().watchSingle());

  @override
  Future<List<MediaAsset>> inRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) => _guard('inRange', () async {
    final rows = await _rangeQuery(fromInclusive, toExclusive).get();
    return rows.map(_toDomain).toList(growable: false);
  });

  @override
  Stream<List<MediaAsset>> watchRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) => _guardStream(
    'watchRange',
    _rangeQuery(
      fromInclusive,
      toExclusive,
    ).watch().map((rows) => rows.map(_toDomain).toList(growable: false)),
  );

  @override
  Stream<List<DayBucket>> watchDayBuckets() => _guardStream(
    'watchDayBuckets',
    _db
        .customSelect(
          // `localtime` usa la zona horaria del dispositivo, la misma con la
          // que se calculan los rangos de día y de mes en Dart. 2 = fecha
          // desconocida. `platform_asset_id` junto a `MAX(capture_date)` toma
          // el valor de la fila más reciente del día (comportamiento
          // documentado de SQLite para una sola agregación MAX/MIN): es la
          // portada.
          "SELECT CASE WHEN capture_date_source = 2 THEN 'none' "
          "ELSE strftime('%Y-%m-%d', capture_date, 'unixepoch', 'localtime') "
          'END AS bucket, COUNT(*) AS total, MAX(capture_date) AS newest, '
          'platform_asset_id AS cover '
          'FROM media_assets GROUP BY bucket',
          readsFrom: {_db.mediaAssets},
        )
        .watch()
        .map(_toDayBuckets),
  );

  Selectable<int> _countQuery() {
    final total = _db.mediaAssets.id.count();
    final query = _db.selectOnly(_db.mediaAssets)..addColumns([total]);
    return query.map((row) => row.read(total) ?? 0);
  }

  SimpleSelectStatement<$MediaAssetsTable, MediaAssetRow> _rangeQuery(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    return _db.select(_db.mediaAssets)
      ..where(
        (t) =>
            t.captureDate.isBiggerOrEqualValue(fromInclusive) &
            t.captureDate.isSmallerThanValue(toExclusive),
      )
      // `id` desempata ráfagas con el mismo segundo de captura.
      ..orderBy([
        (t) => OrderingTerm.desc(t.captureDate),
        (t) => OrderingTerm.desc(t.id),
      ]);
  }

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    try {
      return await body();
    } on AppFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.database,
        '$operation failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw StorageFailure(
        '$operation failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Stream<T> _guardStream<T>(String operation, Stream<T> source) {
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is AppFailure) {
            sink.addError(error, stackTrace);
            return;
          }
          _logger.error(
            LogTag.database,
            '$operation stream failed',
            error: error,
            stackTrace: stackTrace,
          );
          sink.addError(
            StorageFailure(
              '$operation stream failed',
              cause: error,
              stackTrace: stackTrace,
            ),
            stackTrace,
          );
        },
      ),
    );
  }
}

MediaAssetsCompanion _toInsertCompanion(MediaAsset asset) {
  return MediaAssetsCompanion.insert(
    platformAssetId: asset.platformAssetId,
    type: _typeCode(asset.type),
    captureDate: asset.captureDate,
    captureDateSource: _sourceCode(asset.captureDateSource),
    modifiedDate: asset.modifiedDate,
    width: asset.width,
    height: asset.height,
    mimeType: asset.mimeType,
    orientation: Value(asset.orientation),
    durationMs: Value(asset.durationMs),
    latitude: Value(asset.latitude),
    longitude: Value(asset.longitude),
    isFavorite: Value(asset.isFavorite),
  );
}

MediaAssetsCompanion _toPlatformUpdateCompanion(
  MediaAsset asset,
  DateTime now,
) {
  return MediaAssetsCompanion(
    type: Value(_typeCode(asset.type)),
    captureDate: Value(asset.captureDate),
    captureDateSource: Value(_sourceCode(asset.captureDateSource)),
    modifiedDate: Value(asset.modifiedDate),
    width: Value(asset.width),
    height: Value(asset.height),
    orientation: Value(asset.orientation),
    durationMs: Value(asset.durationMs),
    mimeType: Value(asset.mimeType),
    latitude: Value(asset.latitude),
    longitude: Value(asset.longitude),
    updatedAt: Value(now),
  );
}

List<DayBucket> _toDayBuckets(List<QueryRow> rows) {
  final dated = <DayBucket>[];
  DayBucket? undated;
  for (final row in rows) {
    final bucket = row.read<String>('bucket');
    final total = row.read<int>('total');
    final cover = row.read<String>('cover');
    if (bucket == 'none') {
      undated = DayBucket(date: null, count: total, coverAssetId: cover);
      continue;
    }
    final parts = bucket.split('-');
    dated.add(
      DayBucket(
        date: DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        count: total,
        coverAssetId: cover,
      ),
    );
  }
  dated.sort((a, b) => b.date!.compareTo(a.date!));
  return [...dated, ?undated];
}

MediaAsset _toDomain(MediaAssetRow row) {
  return MediaAsset(
    platformAssetId: row.platformAssetId,
    type: _typeFromCode(row.type),
    captureDate: row.captureDate.toUtc(),
    captureDateSource: _sourceFromCode(row.captureDateSource),
    modifiedDate: row.modifiedDate.toUtc(),
    width: row.width,
    height: row.height,
    orientation: row.orientation,
    durationMs: row.durationMs,
    mimeType: row.mimeType,
    latitude: row.latitude,
    longitude: row.longitude,
    isFavorite: row.isFavorite,
  );
}

int _typeCode(MediaType type) => switch (type) {
  MediaType.image => 0,
  MediaType.video => 1,
};

MediaType _typeFromCode(int code) => switch (code) {
  0 => MediaType.image,
  1 => MediaType.video,
  _ => throw StateError('Unknown media type code: $code'),
};

int _sourceCode(CaptureDateSource source) => switch (source) {
  CaptureDateSource.captured => 0,
  CaptureDateSource.modified => 1,
  CaptureDateSource.unknown => 2,
};

CaptureDateSource _sourceFromCode(int code) => switch (code) {
  0 => CaptureDateSource.captured,
  1 => CaptureDateSource.modified,
  2 => CaptureDateSource.unknown,
  _ => throw StateError('Unknown capture date source code: $code'),
};
