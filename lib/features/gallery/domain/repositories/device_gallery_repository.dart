import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

/// Lectura de la galería del dispositivo (adaptador de plataforma).
///
/// Solo la consume el servicio de sincronización: la UI lee del
/// `MediaIndexRepository`. Devuelve metadatos, nunca los bytes del archivo.
///
/// Lanza `PermissionFailure` si no hay permiso de lectura y `GalleryFailure`
/// si falla la lectura.
abstract interface class DeviceGalleryRepository {
  /// Cantidad total de fotos y videos accesibles.
  Future<int> totalCount();

  /// Página `page` (desde 0) de `pageSize` assets, del más reciente al más
  /// antiguo por fecha de creación. Una página vacía indica el final.
  Future<List<MediaAsset>> readPage({required int page, required int pageSize});
}
