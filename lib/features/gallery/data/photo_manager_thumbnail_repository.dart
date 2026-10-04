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
  Future<Uint8List?> load(String platformAssetId, {required int size}) async {
    try {
      final entity = await AssetEntity.fromId(platformAssetId);
      if (entity == null) return null;
      return await entity.thumbnailDataWithSize(ThumbnailSize.square(size));
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
