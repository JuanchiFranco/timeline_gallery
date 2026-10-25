import 'dart:typed_data';

import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/gallery_permission_service.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_file_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/thumbnail_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/services/gallery_sync_service.dart';

/// Servicio de permiso en memoria. `request()` aplica [onRequest] y guarda el
/// resultado como nuevo estado, como haría el sistema.
class FakeGalleryPermissionService implements GalleryPermissionService {
  FakeGalleryPermissionService(
    this.current, {
    this.onRequest = GalleryPermission.granted,
  });

  GalleryPermission current;
  final GalleryPermission onRequest;

  /// Si no es `null`, `status()` falla con él (una vez que se quita, vuelve a
  /// responder normal).
  AppFailure? statusError;

  int requestCalls = 0;
  int openSettingsCalls = 0;
  int manageLimitedCalls = 0;

  @override
  Future<GalleryPermission> status() async {
    final error = statusError;
    if (error != null) throw error;
    return current;
  }

  @override
  Future<GalleryPermission> request() async {
    requestCalls++;
    current = onRequest;
    return current;
  }

  @override
  Future<void> openSystemSettings() async => openSettingsCalls++;

  @override
  Future<void> manageLimitedSelection() async => manageLimitedCalls++;
}

/// Galería del dispositivo en memoria. Entrega los assets del más reciente al
/// más antiguo, como el adaptador real.
class FakeDeviceGalleryRepository implements DeviceGalleryRepository {
  FakeDeviceGalleryRepository([Iterable<MediaAsset> assets = const []])
    : assets = List.of(assets);

  final List<MediaAsset> assets;

  /// Si no es `null`, `readPage` falla al pedir esa página.
  int? failOnPage;

  int readPageCalls = 0;

  List<MediaAsset> get _sorted => List.of(assets)
    ..sort((a, b) {
      final byDate = b.captureDate.compareTo(a.captureDate);
      return byDate != 0
          ? byDate
          : b.platformAssetId.compareTo(a.platformAssetId);
    });

  @override
  Future<int> totalCount() async => assets.length;

  @override
  Future<List<MediaAsset>> readPage({
    required int page,
    required int pageSize,
  }) async {
    readPageCalls++;
    if (failOnPage == page) throw StateError('platform read failed');
    final sorted = _sorted;
    final start = page * pageSize;
    if (start >= sorted.length) return const [];
    final end = start + pageSize < sorted.length
        ? start + pageSize
        : sorted.length;
    return sorted.sublist(start, end);
  }
}

/// Sincronizador que no toca plataforma ni base de datos.
class FakeGallerySyncService implements GallerySyncService {
  FakeGallerySyncService({this.error});

  /// Si no es `null`, `sync` falla con él.
  AppFailure? error;

  int syncCalls = 0;

  /// Cuántas de esas llamadas pidieron un re-escaneo completo.
  int forceFullCalls = 0;

  /// Si se define, se ejecuta dentro de `sync` (para emitir progreso y
  /// quedarse esperando a que el test lo libere).
  Future<void> Function(SyncProgressCallback? onProgress)? script;

  @override
  Future<SyncResult> sync({
    bool forceFull = false,
    SyncProgressCallback? onProgress,
  }) async {
    syncCalls++;
    if (forceFull) forceFullCalls++;
    await script?.call(onProgress);
    final failure = error;
    if (failure != null) throw failure;
    return const SyncResult(mode: SyncMode.incremental);
  }
}

/// Índice en memoria para tests de UI: sirve rangos desde una lista fija.
class FakeMediaIndexRepository implements MediaIndexRepository {
  FakeMediaIndexRepository([Iterable<MediaAsset> assets = const []])
    : assets = List.of(assets);

  final List<MediaAsset> assets;

  List<MediaAsset> _range(DateTime from, DateTime to) =>
      assets
          .where(
            (a) => !a.captureDate.isBefore(from) && a.captureDate.isBefore(to),
          )
          .toList()
        ..sort((a, b) => b.captureDate.compareTo(a.captureDate));

  @override
  Future<List<MediaAsset>> inRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async => _range(fromInclusive, toExclusive);

  @override
  Stream<List<MediaAsset>> watchRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) => Stream.value(_range(fromInclusive, toExclusive));

  @override
  Future<int> count() async => assets.length;

  @override
  Stream<int> watchCount() => Stream.value(assets.length);

  @override
  Stream<List<DayBucket>> watchDayBuckets() {
    // Mismo criterio que la consulta real: día local, portada = el más
    // reciente, y los assets sin fecha confiable en un grupo aparte.
    final byDay = <DateTime, List<MediaAsset>>{};
    final undated = <MediaAsset>[];
    for (final asset in assets) {
      if (asset.captureDateSource == CaptureDateSource.unknown) {
        undated.add(asset);
        continue;
      }
      final local = asset.captureDate.toLocal();
      byDay
          .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
          .add(asset);
    }
    MediaAsset newest(List<MediaAsset> list) =>
        list.reduce((a, b) => b.captureDate.isAfter(a.captureDate) ? b : a);
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return Stream.value([
      for (final day in days)
        DayBucket(
          date: day,
          count: byDay[day]!.length,
          coverAssetId: newest(byDay[day]!).platformAssetId,
        ),
      if (undated.isNotEmpty)
        DayBucket(
          date: null,
          count: undated.length,
          coverAssetId: undated.first.platformAssetId,
        ),
    ]);
  }

  @override
  Future<void> upsertAll(List<MediaAsset> assets) => throw UnimplementedError();

  @override
  Future<int> deleteByPlatformIds(Iterable<String> platformAssetIds) =>
      throw UnimplementedError();

  @override
  Future<Set<String>> knownPlatformIds() => throw UnimplementedError();

  @override
  Future<Map<String, DateTime>> modifiedDatesOf(Iterable<String> ids) =>
      throw UnimplementedError();
}

/// Miniaturas que nunca están disponibles: la UI muestra su placeholder.
class FakeThumbnailRepository implements ThumbnailRepository {
  @override
  Future<Uint8List?> load(
    String platformAssetId, {
    required int size,
    bool preserveAspect = false,
  }) async => null;
}

/// Resuelve todos los assets a la misma ruta (o a ninguna si [path] es `null`).
class FakeMediaFileRepository implements MediaFileRepository {
  FakeMediaFileRepository([this.path = '/fake/video.mp4']);

  final String? path;

  @override
  Future<String?> localPath(String platformAssetId) async => path;
}

/// Estado de sincronización en memoria.
class FakeSyncStateStore implements SyncStateStore {
  final Map<SyncStateKey, String> values = {};

  @override
  Future<String?> read(SyncStateKey key) async => values[key];

  @override
  Future<void> write(SyncStateKey key, String value) async =>
      values[key] = value;

  @override
  Future<void> clear() async => values.clear();
}
