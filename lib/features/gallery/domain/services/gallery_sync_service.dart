import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';

enum SyncMode {
  /// Recorre toda la galería: primer escaneo, reanudación o resync periódico.
  full,

  /// Solo lo nuevo o modificado, empezando por lo más reciente.
  incremental,
}

/// Resumen de una sincronización.
class SyncResult {
  const SyncResult({
    required this.mode,
    this.scanned = 0,
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
  });

  final SyncMode mode;

  /// Assets leídos de la galería.
  final int scanned;
  final int added;
  final int updated;

  /// Assets que ya no están en la galería y se quitaron del índice.
  final int removed;

  bool get hasChanges => added + updated + removed > 0;

  /// Suma dos pasadas consecutivas; el modo es el de la última.
  SyncResult operator +(SyncResult other) => SyncResult(
    mode: other.mode,
    scanned: scanned + other.scanned,
    added: added + other.added,
    updated: updated + other.updated,
    removed: removed + other.removed,
  );
}

typedef SyncProgressCallback = void Function(int processed, int total);

/// Mantiene el índice local alineado con la galería del dispositivo.
abstract interface class GallerySyncService {
  /// Sincroniza. Si ya hay una en curso, devuelve esa misma (no se solapan).
  ///
  /// Lanza `PermissionFailure`, `GalleryFailure`, `StorageFailure` o
  /// `SyncFailure`. Tras un fallo, la siguiente llamada retoma el escaneo
  /// completo donde quedó.
  Future<SyncResult> sync({bool forceFull, SyncProgressCallback? onProgress});
}

/// Estrategia:
///
/// * **Completa** la primera vez, al retomar un escaneo interrumpido (se
///   guarda la página siguiente como checkpoint) y cada [fullResyncInterval]
///   para capturar ediciones antiguas. Es la única que detecta bajas, porque
///   ve todos los ids.
/// * **Incremental** el resto de las veces: lee de lo más reciente a lo más
///   antiguo y se detiene en la primera página sin cambios.
/// * Si tras una incremental el total del dispositivo no coincide con el del
///   índice (bajas, o fotos antiguas importadas), escala a completa.
class DefaultGallerySyncService implements GallerySyncService {
  DefaultGallerySyncService({
    required DeviceGalleryRepository device,
    required MediaIndexRepository index,
    required SyncStateStore state,
    required AppLogger logger,
    DateTime Function()? clock,
    this.pageSize = 500,
    this.fullResyncInterval = const Duration(days: 7),
  }) : _device = device,
       _index = index,
       _state = state,
       _logger = logger,
       _clock = clock ?? DateTime.now;

  final DeviceGalleryRepository _device;
  final MediaIndexRepository _index;
  final SyncStateStore _state;
  final AppLogger _logger;
  final DateTime Function() _clock;

  final int pageSize;
  final Duration fullResyncInterval;

  Future<SyncResult>? _running;

  @override
  Future<SyncResult> sync({
    bool forceFull = false,
    SyncProgressCallback? onProgress,
  }) {
    return _running ??= _run(
      forceFull,
      onProgress,
    ).whenComplete(() => _running = null);
  }

  Future<SyncResult> _run(
    bool forceFull,
    SyncProgressCallback? onProgress,
  ) async {
    try {
      final total = await _device.totalCount();
      final checkpoint = _readInt(await _state.read(SyncStateKey.checkpoint));
      final lastFull = _readDate(
        await _state.read(SyncStateKey.lastFullSyncAt),
      );

      final needsFull =
          forceFull ||
          lastFull == null ||
          checkpoint != null ||
          _clock().toUtc().difference(lastFull) >= fullResyncInterval;

      if (needsFull) {
        final start = forceFull ? 0 : checkpoint ?? 0;
        return await _fullScan(start, total, onProgress);
      }

      final result = await _incremental(total, onProgress);
      if (await _index.count() != total) {
        _logger.info(LogTag.gallerySync, 'count mismatch, escalating to full');
        return result + await _fullScan(0, total, onProgress);
      }
      return result;
    } on AppFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.gallerySync,
        'sync failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw SyncFailure('sync failed', cause: error, stackTrace: stackTrace);
    }
  }

  Future<SyncResult> _fullScan(
    int startPage,
    int total,
    SyncProgressCallback? onProgress,
  ) async {
    final known = await _index.modifiedDates();
    // Solo un escaneo desde la página 0 ve todos los ids y puede inferir bajas.
    final seen = <String>{};
    var scanned = 0;
    var added = 0;
    var updated = 0;

    for (var page = startPage; ; page++) {
      final assets = await _device.readPage(page: page, pageSize: pageSize);
      if (assets.isEmpty) break;

      await _index.upsertAll(assets);
      for (final asset in assets) {
        final previous = known[asset.platformAssetId];
        if (previous == null) {
          added++;
        } else if (previous != asset.modifiedDate) {
          updated++;
        }
        if (startPage == 0) seen.add(asset.platformAssetId);
      }
      scanned += assets.length;

      // Tras confirmar la página: si se interrumpe, se retoma desde la
      // siguiente sin perder lo ya indexado.
      await _state.write(SyncStateKey.checkpoint, '${page + 1}');
      onProgress?.call(page * pageSize + assets.length, total);

      if (assets.length < pageSize) break;
    }

    var removed = 0;
    if (startPage == 0) {
      final gone = known.keys.where((id) => !seen.contains(id)).toList();
      removed = await _index.deleteByPlatformIds(gone);
    }

    await _state.write(SyncStateKey.checkpoint, '');
    final now = _clock().toUtc().toIso8601String();

    final result = SyncResult(
      mode: SyncMode.full,
      scanned: scanned,
      added: added,
      updated: updated,
      removed: removed,
    );

    // Un escaneo retomado no vio las páginas anteriores: si el total no
    // cuadra, hay que repetirlo completo para detectar bajas.
    if (startPage > 0 && await _index.count() != total) {
      _logger.info(LogTag.gallerySync, 'resumed scan mismatch, rescanning');
      return result + await _fullScan(0, total, onProgress);
    }

    await _state.write(SyncStateKey.lastFullSyncAt, now);
    await _state.write(SyncStateKey.lastIncrementalSyncAt, now);
    _logger.info(
      LogTag.gallerySync,
      'full sync: ${result.scanned} scanned, ${result.added} added, '
      '${result.updated} updated, ${result.removed} removed',
    );
    return result;
  }

  Future<SyncResult> _incremental(
    int total,
    SyncProgressCallback? onProgress,
  ) async {
    final known = await _index.modifiedDates();
    var scanned = 0;
    var added = 0;
    var updated = 0;

    for (var page = 0; ; page++) {
      final assets = await _device.readPage(page: page, pageSize: pageSize);
      if (assets.isEmpty) break;
      scanned += assets.length;

      final changed = <MediaAsset>[];
      for (final asset in assets) {
        final previous = known[asset.platformAssetId];
        if (previous == null) {
          added++;
          changed.add(asset);
        } else if (previous != asset.modifiedDate) {
          updated++;
          changed.add(asset);
        }
      }

      // Orden por fecha de captura: una página sin cambios indica que el
      // resto ya está indexado.
      if (changed.isEmpty) break;
      await _index.upsertAll(changed);
      onProgress?.call(page * pageSize + assets.length, total);

      if (assets.length < pageSize) break;
    }

    await _state.write(
      SyncStateKey.lastIncrementalSyncAt,
      _clock().toUtc().toIso8601String(),
    );
    final result = SyncResult(
      mode: SyncMode.incremental,
      scanned: scanned,
      added: added,
      updated: updated,
    );
    _logger.info(
      LogTag.gallerySync,
      'incremental sync: ${result.scanned} scanned, ${result.added} added, '
      '${result.updated} updated',
    );
    return result;
  }

  /// El checkpoint vacío significa "sin escaneo pendiente" (el store no
  /// permite borrar una clave suelta).
  int? _readInt(String? raw) =>
      raw == null || raw.isEmpty ? null : int.tryParse(raw);

  DateTime? _readDate(String? raw) =>
      raw == null || raw.isEmpty ? null : DateTime.tryParse(raw)?.toUtc();
}
