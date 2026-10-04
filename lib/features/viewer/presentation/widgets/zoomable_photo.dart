import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_image.dart';

/// Lado más largo de la vista previa. Alcanza para una pantalla densa con
/// zoom moderado sin decodificar el original completo (puede pesar decenas de
/// MB y no siempre es un formato que Flutter sepa leer, como HEIC en Android).
const _previewSize = 2048;

const _maxScale = 5.0;
const _doubleTapScale = 2.5;

/// Foto a pantalla completa con zoom por pellizco y doble toque.
///
/// Avisa con [onZoomChanged] cuando hay zoom, para que el contenedor
/// desactive el deslizamiento entre assets mientras se mueve la imagen.
class ZoomablePhoto extends ConsumerStatefulWidget {
  const ZoomablePhoto({
    required this.asset,
    required this.onZoomChanged,
    required this.onTap,
    super.key,
  });

  final MediaAsset asset;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  ConsumerState<ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends ConsumerState<ZoomablePhoto> {
  final _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
    } else {
      // Acerca manteniendo bajo el dedo el punto tocado.
      final p = _doubleTapPosition;
      _transform.value =
          Matrix4.translationValues(
            -p.dx * (_doubleTapScale - 1),
            -p.dy * (_doubleTapScale - 1),
            0,
          ).multiplied(
            Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1),
          );
    }
    _syncZoomState();
  }

  @override
  Widget build(BuildContext context) {
    final image = ThumbnailImage(
      repository: ref.watch(thumbnailRepositoryProvider),
      assetId: widget.asset.platformAssetId,
      size: _previewSize,
      preserveAspect: true,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: _maxScale,
        onInteractionEnd: (_) => _syncZoomState(),
        child: SizedBox.expand(
          child: Image(
            image: image,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                frame == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  )
                : child,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white54),
                  SizedBox(height: 8),
                  Text(
                    'No se pudo cargar la foto',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
