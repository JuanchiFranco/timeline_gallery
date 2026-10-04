import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/moment_block.dart';

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
            MomentBlock(moment: moment, showTime: date != null),
        ],
      ),
    );
  }
}
