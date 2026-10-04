import 'dart:math' as math;
import 'dart:typed_data';

import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/thumbnail_repository.dart';
import 'package:photo_manager/photo_manager.dart';

/// Miniaturas con `photo_manager`: el sistema ya mantiene su propia caché de
/// miniaturas, así que no se duplica en disco.
class PhotoManagerThumbnailRepository implements ThumbnailRepository {
  PhotoManagerThumbnailRepository(this._logger);

  final AppLogger _logger;

  @override
  Future<Uint8List?> load(
    String platformAssetId, {
    required int size,
    bool preserveAspect = false,
  }) async {
    try {
      final entity = await AssetEntity.fromId(platformAssetId);
      if (entity == null) return null;
      return await entity.thumbnailDataWithSize(
        preserveAspect ? _fitted(entity, size) : ThumbnailSize.square(size),
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.platform,
        'thumbnail load failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw GalleryFailure(
        'thumbnail load failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Tamaño que cabe en [maxSide] x [maxSide] con la proporción del asset,
/// sin superar su resolución original.
ThumbnailSize _fitted(AssetEntity entity, int maxSide) {
  final width = entity.orientatedWidth;
  final height = entity.orientatedHeight;
  final longest = math.max(width, height);
  if (longest <= 0) return ThumbnailSize.square(maxSide);
  final scale = math.min(1.0, maxSide / longest);
  return ThumbnailSize(
    math.max(1, (width * scale).round()),
    math.max(1, (height * scale).round()),
  );
}
