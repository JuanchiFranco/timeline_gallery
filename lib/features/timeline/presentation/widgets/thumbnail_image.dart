import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/thumbnail_repository.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_queue.dart';

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
    this.queue,
  });

  final ThumbnailRepository repository;
  final String assetId;
  final int size;

  /// Conserva la proporción del original (visor) en vez de recortar a cuadrado.
  final bool preserveAspect;

  /// Cola que acota y prioriza la carga (para las grillas). Sin cola, la carga
  /// es inmediata, como necesita el visor.
  final ThumbnailQueue? queue;

  /// Clave que identifica esta miniatura en la [queue] y en el caché.
  String get queueKey =>
      keyFor(assetId: assetId, size: size, preserveAspect: preserveAspect);

  static String keyFor({
    required String assetId,
    required int size,
    bool preserveAspect = false,
  }) => '$assetId@$size${preserveAspect ? 'a' : ''}';

  @override
  Future<ThumbnailImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ThumbnailImage>(this);

  @override
  ImageStreamCompleter loadImage(
    ThumbnailImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key, decode));
  }

  Future<ImageInfo> _load(
    ThumbnailImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      Future<Uint8List?> read() =>
          repository.load(assetId, size: size, preserveAspect: preserveAspect);
      final bytes = await (queue?.run(queueKey, read) ?? read());
      if (bytes == null) {
        throw StateError('thumbnail unavailable');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await decode(buffer);
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } on Object {
      // El `ImageCache` guarda también las cargas fallidas: sin desalojarla, un
      // fallo transitorio (o una carga cancelada por la cola al salir de
      // pantalla) dejaría esta miniatura rota hasta reiniciar la app.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
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
