import 'dart:typed_data';

/// Miniaturas y vistas previas de la galería del dispositivo, resueltas bajo
/// demanda a partir del `platformAssetId`. Nunca se guardan en el índice.
abstract interface class ThumbnailRepository {
  /// Bytes de una imagen de hasta [size] píxeles, o `null` si el asset ya no
  /// existe en el dispositivo.
  ///
  /// Por defecto es cuadrada ([size] x [size], para las grillas). Con
  /// [preserveAspect] conserva la proporción del original y [size] es el lado
  /// más largo (para el visor); nunca amplía por encima del original.
  ///
  /// Lanza `GalleryFailure` si falla la lectura.
  Future<Uint8List?> load(
    String platformAssetId, {
    required int size,
    bool preserveAspect = false,
  });
}
