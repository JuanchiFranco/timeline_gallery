import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/formatting/duration_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_image.dart';

/// Lado en píxeles de la miniatura pedida a la plataforma. Cubre una celda de
/// ~90 dp a 3x de densidad sin pedir más datos de los necesarios.
const _thumbnailSize = 300;

/// Celda cuadrada con la miniatura de un asset. Si es video muestra la
/// duración; si [overflow] > 0 se atenúa y muestra "+N".
class ThumbnailTile extends ConsumerWidget {
  const ThumbnailTile({
    required this.asset,
    this.overflow = 0,
    this.onTap,
    super.key,
  });

  final MediaAsset asset;
  final int overflow;

  /// Qué hacer al tocar la miniatura (por ejemplo, abrir el visor).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repository = ref.watch(thumbnailRepositoryProvider);

    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Image(
              image: ThumbnailImage(
                repository: repository,
                assetId: asset.platformAssetId,
                size: _thumbnailSize,
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                asset.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (asset.isVideo && overflow == 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: _Badge(
                icon: Icons.play_arrow_rounded,
                label: formatDuration(asset.duration),
              ),
            ),
          if (overflow > 0)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '+$overflow',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: asset.isVideo ? 'Abrir video' : 'Abrir foto',
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: tile),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            if (label.isNotEmpty)
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
