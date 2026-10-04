import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/thumbnail_repository.dart';

/// Miniatura de un asset como [ImageProvider]. La clave es (id, tamaño), así
/// el `ImageCache` de Flutter evita volver a pedirla a la plataforma al hacer
/// scroll de ida y vuelta.
@immutable
class ThumbnailImage extends ImageProvider<ThumbnailImage> {
  const ThumbnailImage({
    required this.repository,
    required this.assetId,
    required this.size,
    this.preserveAspect = false,
  });

  final ThumbnailRepository repository;
  final String assetId;
  final int size;

  /// Conserva la proporción del original (visor) en vez de recortar a cuadrado.
  final bool preserveAspect;

  @override
  Future<ThumbnailImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ThumbnailImage>(this);

  @override
  ImageStreamCompleter loadImage(
    ThumbnailImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(decode));
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final bytes = await repository.load(
      assetId,
      size: size,
      preserveAspect: preserveAspect,
    );
    if (bytes == null) {
      throw StateError('thumbnail unavailable');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is ThumbnailImage &&
      assetId == other.assetId &&
      size == other.size &&
      preserveAspect == other.preserveAspect;

  @override
  int get hashCode => Object.hash(assetId, size, preserveAspect);
}
