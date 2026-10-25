import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_image.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_queue.dart';

/// Miniatura de una grilla. Mientras está montada declara su interés en la
/// [ThumbnailQueue]: si sale de pantalla antes de que le toque cargar, la carga
/// se descarta y no llega a la plataforma.
class ThumbnailPicture extends ConsumerStatefulWidget {
  const ThumbnailPicture({
    required this.assetId,
    required this.size,
    required this.fallback,
    super.key,
  });

  final String assetId;
  final int size;

  /// Lo que se ve si la miniatura no está disponible.
  final Widget fallback;

  @override
  ConsumerState<ThumbnailPicture> createState() => _ThumbnailPictureState();
}

class _ThumbnailPictureState extends ConsumerState<ThumbnailPicture> {
  late final ThumbnailQueue _queue = ref.read(thumbnailQueueProvider);
  late String _key;

  String _keyFor(ThumbnailPicture widget) =>
      ThumbnailImage.keyFor(assetId: widget.assetId, size: widget.size);

  @override
  void initState() {
    super.initState();
    _key = _keyFor(widget);
    _queue.addInterest(_key);
  }

  @override
  void didUpdateWidget(ThumbnailPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _keyFor(widget);
    if (next == _key) return;
    _queue
      ..removeInterest(_key)
      ..addInterest(next);
    _key = next;
  }

  @override
  void dispose() {
    _queue.removeInterest(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: ThumbnailImage(
        repository: ref.watch(thumbnailRepositoryProvider),
        assetId: widget.assetId,
        size: widget.size,
        queue: _queue,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}
