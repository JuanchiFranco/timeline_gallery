import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';

/// Permiso de acceso a la galería del dispositivo.
///
/// Los errores de plataforma se traducen a `PermissionFailure`.
abstract interface class GalleryPermissionService {
  /// Estado actual **sin** mostrar ningún diálogo.
  Future<GalleryPermission> status();

  /// Muestra el diálogo del sistema si corresponde y devuelve el resultado.
  Future<GalleryPermission> request();

  /// Abre los ajustes del sistema para esta app.
  Future<void> openSystemSettings();

  /// Con acceso limitado, permite ampliar la selección de elementos.
  Future<void> manageLimitedSelection();
}
