import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/platform_asset_mapper.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/gallery_permission_service.dart';
import 'package:photo_manager/photo_manager.dart';

/// Lee la galería del dispositivo con `photo_manager`.
class PhotoManagerGalleryRepository implements DeviceGalleryRepository {
  PhotoManagerGalleryRepository(this._permissions, this._logger);

  final GalleryPermissionService _permissions;
  final AppLogger _logger;

  /// Más reciente primero, igual que el contrato del repositorio.
  static final _filter = FilterOptionGroup(
    orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  @override
  Future<int> totalCount() => _guard('totalCount', () async {
    final all = await _allAssetsPath();
    return all == null ? 0 : await all.assetCountAsync;
  });

  @override
  Future<List<MediaAsset>> readPage({
    required int page,
    required int pageSize,
  }) => _guard('readPage', () async {
    final all = await _allAssetsPath();
    if (all == null) return const <MediaAsset>[];
    final entities = await all.getAssetListPaged(page: page, size: pageSize);
    return entities.map(_toDomain).toList(growable: false);
  });

  /// El álbum virtual "todas" que agrupa fotos y videos de todo el
  /// dispositivo. `null` si la galería está vacía.
  Future<AssetPathEntity?> _allAssetsPath() async {
    final permission = await _permissions.status();
    if (!permission.canRead) {
      throw const PermissionFailure('gallery read without permission');
    }
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
      filterOption: _filter,
    );
    return paths.isEmpty ? null : paths.first;
  }

  MediaAsset _toDomain(AssetEntity entity) {
    return mapPlatformAsset(
      id: entity.id,
      isVideo: entity.type == AssetType.video,
      createSeconds: entity.createDateSecond,
      modifiedSeconds: entity.modifiedDateSecond,
      width: entity.width,
      height: entity.height,
      orientation: entity.orientation,
      durationSeconds: entity.duration,
      latitude: entity.latitude,
      longitude: entity.longitude,
      mimeType: entity.mimeType,
    );
  }

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    try {
      return await body();
    } on AppFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.platform,
        'gallery $operation failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw GalleryFailure(
        'gallery $operation failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
