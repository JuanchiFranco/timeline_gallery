import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/formatting/duration_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_image.dart';
import 'package:galeria_eventos/features/viewer/presentation/providers/viewer_providers.dart';
import 'package:video_player/video_player.dart';

const _posterSize = 1024;
const _controlsHeight = 56.0;

/// Video del visor. Muestra un póster y solo prepara el reproductor cuando el
/// usuario toca reproducir: pasar rápido por varios videos no abre varios
/// decodificadores.
class VideoViewer extends ConsumerStatefulWidget {
  const VideoViewer({required this.asset, required this.onTap, super.key});

  final MediaAsset asset;
  final VoidCallback onTap;

  @override
  ConsumerState<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends ConsumerState<VideoViewer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    VideoPlayerController? controller;
    try {
      final path = await ref
          .read(mediaFileRepositoryProvider)
          .localPath(widget.asset.platformAssetId);
      if (path == null) throw StateError('video unavailable');
      controller = ref.read(videoControllerFactoryProvider)(path);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } on Object {
      // Sin `await`: si la creación falló, `dispose()` espera para siempre un
      // completer que nunca se completa y la pantalla quedaría cargando.
      unawaited(controller?.dispose());
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: controller == null
          ? _Poster(
              asset: widget.asset,
              loading: _loading,
              failed: _failed,
              onPlay: _start,
            )
          : _Player(controller: controller),
    );
  }
}

class _Poster extends ConsumerWidget {
  const _Poster({
    required this.asset,
    required this.loading,
    required this.failed,
    required this.onPlay,
  });

  final MediaAsset asset;
  final bool loading;
  final bool failed;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: ThumbnailImage(
            repository: ref.watch(thumbnailRepositoryProvider),
            assetId: asset.platformAssetId,
            size: _posterSize,
            preserveAspect: true,
          ),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        Center(
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      tooltip: 'Reproducir',
                      iconSize: 48,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    if (failed) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'No se pudo reproducir el video',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: _Controls(controller: controller)),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final total = value.duration.inMilliseconds;
        final position = value.position.inMilliseconds.clamp(0, total);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          // Altura fija: un `Slider` se expande a toda la altura disponible y,
          // sin este límite, la barra queda centrada en medio de la pantalla.
          child: SizedBox(
            height: _controlsHeight,
            child: Row(
              children: [
                IconButton(
                  tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
                  color: Colors.white,
                  onPressed: () =>
                      value.isPlaying ? controller.pause() : controller.play(),
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: position.toDouble(),
                    max: total > 0 ? total.toDouble() : 1,
                    onChanged: total > 0
                        ? (ms) => controller.seekTo(
                            Duration(milliseconds: ms.round()),
                          )
                        : null,
                  ),
                ),
                Text(
                  '${formatDuration(value.position)} / ${formatDuration(value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
