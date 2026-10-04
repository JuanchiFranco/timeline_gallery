import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/viewer/presentation/providers/viewer_providers.dart';
import 'package:galeria_eventos/features/viewer/presentation/widgets/video_viewer.dart';
import 'package:galeria_eventos/features/viewer/presentation/widgets/zoomable_photo.dart';
import 'package:go_router/go_router.dart';

/// Visor a pantalla completa. Desliza entre los assets del mismo día,
/// empezando en [assetId].
class ViewerPage extends ConsumerWidget {
  const ViewerPage({required this.dayParam, required this.assetId, super.key});

  /// Parámetro de fecha de la ruta (`2026-09-23` o `sin-fecha`).
  final String dayParam;
  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(viewerAssetsProvider(dayParam));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: assets.when(
          loading: () => const _WithBack(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          ),
          error: (error, _) => _WithBack(
            child: _Message(
              error is AppFailure
                  ? error.userMessage
                  : const UnexpectedFailure('unclassified').userMessage,
            ),
          ),
          data: (list) => list.isEmpty
              ? const _WithBack(child: _Message('Este recuerdo ya no está'))
              : _ViewerPager(assets: list, initialId: assetId),
        ),
      ),
    );
  }
}

class _ViewerPager extends ConsumerStatefulWidget {
  const _ViewerPager({required this.assets, required this.initialId});

  final List<MediaAsset> assets;
  final String initialId;

  @override
  ConsumerState<_ViewerPager> createState() => _ViewerPagerState();
}

class _ViewerPagerState extends ConsumerState<_ViewerPager> {
  late final PageController _controller;
  late String _currentId;
  bool _zoomed = false;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    final index = _indexOf(widget.initialId);
    // Si el asset ya no existe (se borró), se abre el primero del día.
    _currentId = widget.assets[index < 0 ? 0 : index].platformAssetId;
    _controller = PageController(initialPage: index < 0 ? 0 : index);
  }

  @override
  void didUpdateWidget(_ViewerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La sincronización puede agregar o quitar assets del día y correr los
    // índices: se vuelve a la página del asset que se estaba viendo.
    final index = _indexOf(_currentId);
    if (index < 0) {
      _currentId = widget.assets.first.platformAssetId;
    }
    final target = index < 0 ? 0 : index;
    if (widget.assets.length != oldWidget.assets.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(target);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(String id) =>
      widget.assets.indexWhere((a) => a.platformAssetId == id);

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    final assets = widget.assets;
    final index = _indexOf(_currentId).clamp(0, assets.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          // Con zoom, arrastrar mueve la imagen y no cambia de asset.
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: assets.length,
          onPageChanged: (i) => setState(() {
            _currentId = assets[i].platformAssetId;
            _zoomed = false;
          }),
          itemBuilder: (context, i) {
            final asset = assets[i];
            return asset.isVideo
                ? VideoViewer(
                    key: ValueKey(asset.platformAssetId),
                    asset: asset,
                    onTap: _toggleChrome,
                  )
                : ZoomablePhoto(
                    key: ValueKey(asset.platformAssetId),
                    asset: asset,
                    onTap: _toggleChrome,
                    onZoomChanged: (zoomed) => setState(() => _zoomed = zoomed),
                  );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: AnimatedOpacity(
              opacity: _chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: _TopBar(
                asset: assets[index],
                position: index + 1,
                total: assets.length,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.asset,
    required this.position,
    required this.total,
  });

  final MediaAsset asset;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dated = asset.captureDateSource != CaptureDateSource.unknown;
    final local = asset.captureDate.toLocal();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: Row(
            children: [
              const _BackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dated
                          ? EsDateFormat.day(local, today: DateTime.now())
                          : 'Fecha desconocida',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (dated)
                      Text(
                        EsDateFormat.timeRange(local, local),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$position / $total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Volver',
      color: Colors.white,
      icon: const Icon(Icons.arrow_back),
      // Si se llegó por un enlace directo no hay a dónde volver: al inicio.
      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
    );
  }
}

/// Estados sin contenido (cargando, error, vacío) con botón para volver.
class _WithBack extends StatelessWidget {
  const _WithBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const SafeArea(
          child: Align(alignment: Alignment.topLeft, child: _BackButton()),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
