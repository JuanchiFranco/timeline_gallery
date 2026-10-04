import 'dart:typed_data';

import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/gallery_permission_service.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_index_repository.dart';
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

  int requestCalls = 0;
  int openSettingsCalls = 0;
  int manageLimitedCalls = 0;

  @override
  Future<GalleryPermission> status() async => current;

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

  @override
  Future<SyncResult> sync({
    bool forceFull = false,
    SyncProgressCallback? onProgress,
  }) async {
    syncCalls++;
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
  Stream<List<MonthBucket>> watchMonthBuckets() =>
      throw UnimplementedError('override monthBucketsProvider in the test');

  @override
  Future<void> upsertAll(List<MediaAsset> assets) => throw UnimplementedError();

  @override
  Future<int> deleteByPlatformIds(Iterable<String> platformAssetIds) =>
      throw UnimplementedError();

  @override
  Future<Set<String>> knownPlatformIds() => throw UnimplementedError();

  @override
  Future<Map<String, DateTime>> modifiedDates() => throw UnimplementedError();
}

/// Miniaturas que nunca están disponibles: la UI muestra su placeholder.
class FakeThumbnailRepository implements ThumbnailRepository {
  @override
  Future<Uint8List?> load(String platformAssetId, {required int size}) async =>
      null;
}
