import 'package:flutter/material.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';
import 'package:galeria_eventos/features/viewer/domain/viewer.dart';
import 'package:go_router/go_router.dart';

const _columns = 4;
const _spacing = 4.0;

/// "08:00 – 08:10 · 2 fotos, 1 video". Sin hora si [showTime] es falso (el
/// grupo sin fecha no tiene hora que mostrar).
String momentLabel(TimelineMoment moment, {required bool showTime}) {
  final photos = moment.assets.where((a) => !a.isVideo).length;
  final videos = moment.count - photos;
  final summary = [
    if (photos > 0) photos == 1 ? '1 foto' : '$photos fotos',
    if (videos > 0) videos == 1 ? '1 video' : '$videos videos',
  ].join(', ');
  return [
    if (showTime) EsDateFormat.timeRange(moment.start, moment.end),
    summary,
  ].join(' · ');
}

/// Momento compacto para el timeline: hasta [maxTiles] miniaturas y el resto
/// resumido como "+N" en la última celda.
class MomentBlock extends StatelessWidget {
  const MomentBlock({
    required this.moment,
    required this.showTime,
    this.maxTiles = 8,
    super.key,
  });

  final TimelineMoment moment;
  final bool showTime;
  final int maxTiles;

  @override
  Widget build(BuildContext context) {
    final shown = moment.assets.take(maxTiles).toList();
    final hidden = moment.count - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              momentLabel(moment, showTime: showTime),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          GridView.count(
            crossAxisCount: _columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < shown.length; i++)
                ThumbnailTile(
                  key: ValueKey(shown[i].platformAssetId),
                  asset: shown[i],
                  onTap: () => context.push(viewerLocation(shown[i])),
                  // La última celda visible cuenta también como parte del resto.
                  overflow: hidden > 0 && i == shown.length - 1
                      ? hidden + 1
                      : 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Momento completo como slivers: encabezado y todas las miniaturas, que se
/// construyen de forma perezosa. Para pantallas que muestran un solo día.
class MomentSliver extends StatelessWidget {
  const MomentSliver({required this.moment, required this.showTime, super.key});

  final TimelineMoment moment;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final assets = moment.assets;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              momentLabel(moment, showTime: showTime),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: _spacing,
              crossAxisSpacing: _spacing,
            ),
            itemCount: assets.length,
            itemBuilder: (context, index) => ThumbnailTile(
              key: ValueKey(assets[index].platformAssetId),
              asset: assets[index],
              onTap: () => context.push(viewerLocation(assets[index])),
            ),
          ),
        ),
      ],
    );
  }
}
