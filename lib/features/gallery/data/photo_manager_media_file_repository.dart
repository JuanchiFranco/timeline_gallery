import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_file_repository.dart';
import 'package:photo_manager/photo_manager.dart';

/// Resuelve la ruta del archivo con `photo_manager`. En iOS, si el original
/// está en iCloud, la plataforma lo descarga antes de devolver la ruta.
class PhotoManagerMediaFileRepository implements MediaFileRepository {
  PhotoManagerMediaFileRepository(this._logger);

  final AppLogger _logger;

  @override
  Future<String?> localPath(String platformAssetId) async {
    try {
      final entity = await AssetEntity.fromId(platformAssetId);
      final file = await entity?.file;
      return file?.path;
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.platform,
        'media file resolve failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw GalleryFailure(
        'media file resolve failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
