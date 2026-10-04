import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/calendar/domain/calendar.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_image.dart';

/// Lado en píxeles de la portada de un día en la grilla.
const _coverSize = 200;

/// Grilla de un mes. Cada día con assets muestra su portada y la cantidad; los
/// demás, solo el número. Mientras el mes carga se ve la grilla vacía, así la
/// pantalla no salta.
class CalendarMonthGrid extends ConsumerWidget {
  const CalendarMonthGrid({
    required this.month,
    required this.onOpenDay,
    DateTime? today,
    super.key,
  }) : _today = today;

  final MonthKey month;
  final ValueChanged<DateTime> onOpenDay;
  final DateTime? _today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(monthDaysProvider(month));
    final summaries = summarizeDays(days.value ?? const []);
    final now = _today ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final date in monthGridCells(month.year, month.month))
                if (date == null)
                  const SizedBox.shrink()
                else
                  _DayCell(
                    date: date,
                    summary: summaries[date.day],
                    isToday: date == today,
                    onTap: () => onOpenDay(date),
                  ),
            ],
          ),
        ),
        if (days.hasError)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              days.error is AppFailure
                  ? (days.error! as AppFailure).userMessage
                  : const UnexpectedFailure('unclassified').userMessage,
            ),
          ),
      ],
    );
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.date,
    required this.summary,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final DaySummary? summary;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = this.summary;
    final hasMemories = summary != null;

    final label =
        '${date.day} de ${EsDateFormat.month(date.month).toLowerCase()}'
        '${hasMemories ? ', ${summary.count} recuerdos' : ''}';

    final cell = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: hasMemories
                ? scheme.surfaceContainerHighest
                : scheme.surfaceContainerLow,
          ),
          if (hasMemories) ...[
            Image(
              image: ThumbnailImage(
                repository: ref.watch(thumbnailRepositoryProvider),
                assetId: summary.cover.platformAssetId,
                size: _coverSize,
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const ColoredBox(color: Colors.black38),
          ],
          Center(
            child: Text(
              '${date.day}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: hasMemories ? Colors.white : scheme.onSurfaceVariant,
                fontWeight: hasMemories ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (hasMemories)
            Positioned(
              right: 4,
              bottom: 2,
              child: Text(
                '${summary.count}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          if (isToday)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.primary, width: 2),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: label,
      button: hasMemories,
      excludeSemantics: true,
      child: hasMemories ? GestureDetector(onTap: onTap, child: cell) : cell,
    );
  }
}
