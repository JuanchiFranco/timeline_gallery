import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/gallery_permission_service.dart';
import 'package:photo_manager/photo_manager.dart';

/// Permiso de galería sobre `photo_manager`.
class PhotoManagerPermissionService implements GalleryPermissionService {
  PhotoManagerPermissionService(this._logger);

  final AppLogger _logger;

  /// Lectura de fotos y videos. No se pide `ACCESS_MEDIA_LOCATION`: la
  /// ubicación no hace falta para el timeline (ver docs/decisions.md, D14).
  static const _option = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
    iosAccessLevel: IosAccessLevel.readWrite,
  );

  @override
  Future<GalleryPermission> status() => _guard(
    'status',
    () async => galleryPermissionFrom(
      await PhotoManager.getPermissionState(requestOption: _option),
    ),
  );

  @override
  Future<GalleryPermission> request() => _guard(
    'request',
    () async => galleryPermissionFrom(
      await PhotoManager.requestPermissionExtend(requestOption: _option),
    ),
  );

  @override
  Future<void> openSystemSettings() =>
      _guard('openSystemSettings', PhotoManager.openSetting);

  @override
  Future<void> manageLimitedSelection() =>
      _guard('manageLimitedSelection', PhotoManager.presentLimited);

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    try {
      return await body();
    } on AppFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(
        LogTag.platform,
        'permission $operation failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw PermissionFailure(
        'permission $operation failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Traduce el estado de `photo_manager` al del dominio.
GalleryPermission galleryPermissionFrom(PermissionState state) {
  return switch (state) {
    PermissionState.notDetermined => GalleryPermission.notDetermined,
    PermissionState.authorized => GalleryPermission.granted,
    PermissionState.limited => GalleryPermission.limited,
    PermissionState.denied => GalleryPermission.denied,
    PermissionState.restricted => GalleryPermission.restricted,
  };
}
