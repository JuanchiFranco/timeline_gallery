/// Acceso al archivo original de un asset, para reproducirlo.
abstract interface class MediaFileRepository {
  /// Ruta local de un archivo que el reproductor puede abrir, o `null` si el
  /// asset ya no existe en el dispositivo. El archivo es del sistema: la app
  /// no lo copia ni lo borra.
  ///
  /// Lanza `GalleryFailure` si falla la lectura.
  Future<String?> localPath(String platformAssetId);
}
