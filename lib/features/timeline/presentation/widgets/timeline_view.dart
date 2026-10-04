import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_tile.dart';

/// Máximo de miniaturas por momento (2 filas de 4). El resto se resume como
/// "+N" en la última celda; verlas todas es trabajo del visor (Fase 7).
const _maxTilesPerMoment = 8;
const _columns = 4;

/// Línea de tiempo: año → mes → día → momento. Los meses se construyen de
/// forma perezosa y cada uno consulta solo su rango al índice.
class TimelineView extends StatelessWidget {
  const TimelineView({required this.buckets, super.key});

  final List<MonthBucket> buckets;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: buckets.length,
      itemBuilder: (context, index) {
        final bucket = buckets[index];
        final previous = index == 0 ? null : buckets[index - 1];
        final startsYear =
            !bucket.key.isUndated &&
            (previous == null || previous.key.year != bucket.key.year);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (startsYear) _YearHeader(bucket.key.year),
            _MonthSection(bucket: bucket),
          ],
        );
      },
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader(this.year);

  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Semantics(
        header: true,
        child: Text(
          '$year',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _MonthSection extends ConsumerWidget {
  const _MonthSection({required this.bucket});

  final MonthBucket bucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final days = ref.watch(monthDaysProvider(bucket.key));
    final title = bucket.key.isUndated
        ? 'Sin fecha'
        : EsDateFormat.month(bucket.key.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              '$title · ${bucket.count}',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        days.when(
          // Reserva altura para que el scroll no salte al llegar los datos.
          loading: () => const SizedBox(height: 160),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              error is AppFailure
                  ? error.userMessage
                  : const UnexpectedFailure('unclassified').userMessage,
            ),
          ),
          data: (days) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final day in days) _DaySection(day: day)],
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final TimelineDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = day.date;
    final label = date == null
        ? 'Fecha desconocida'
        : EsDateFormat.day(date, today: DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final moment in day.moments)
            _MomentBlock(moment: moment, showTime: date != null),
        ],
      ),
    );
  }
}

class _MomentBlock extends StatelessWidget {
  const _MomentBlock({required this.moment, required this.showTime});

  final TimelineMoment moment;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = moment.assets.take(_maxTilesPerMoment).toList();
    final hidden = moment.count - shown.length;
    final photos = moment.assets.where((a) => !a.isVideo).length;
    final videos = moment.count - photos;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              [
                if (showTime) EsDateFormat.timeRange(moment.start, moment.end),
                _summary(photos, videos),
              ].join(' · '),
              style: theme.textTheme.labelMedium,
            ),
          ),
          GridView.count(
            crossAxisCount: _columns,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < shown.length; i++)
                ThumbnailTile(
                  key: ValueKey(shown[i].platformAssetId),
                  asset: shown[i],
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

String _summary(int photos, int videos) {
  final parts = [
    if (photos > 0) photos == 1 ? '1 foto' : '$photos fotos',
    if (videos > 0) videos == 1 ? '1 video' : '$videos videos',
  ];
  return parts.join(', ');
}
