import 'dart:typed_data';

/// Miniaturas de la galería del dispositivo, resueltas bajo demanda a partir
/// del `platformAssetId`. Nunca se guardan en el índice.
abstract interface class ThumbnailRepository {
  /// Bytes de una miniatura cuadrada de [size] píxeles de lado, o `null` si el
  /// asset ya no existe en el dispositivo.
  ///
  /// Lanza `GalleryFailure` si falla la lectura.
  Future<Uint8List?> load(String platformAssetId, {required int size});
}
