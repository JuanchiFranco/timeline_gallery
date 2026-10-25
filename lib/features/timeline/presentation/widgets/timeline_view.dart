import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_rows.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/moment_block.dart';

/// Línea de tiempo: año → mes → día → momento, como una lista plana y
/// perezosa de filas. Cada día pide sus propios assets solo cuando aparece en
/// pantalla, así un mes con miles de fotos cuesta lo mismo que uno con diez.
class TimelineView extends StatelessWidget {
  const TimelineView({required this.rows, super.key});

  final List<TimelineRow> rows;

  @override
  Widget build(BuildContext context) {
    final indexById = {for (var i = 0; i < rows.length; i++) rows[i].id: i};
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      // Conserva el estado de cada fila cuando la lista cambia por la
      // sincronización (se agregan días arriba y los índices se corren).
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indexById[key.value] : null,
      itemBuilder: (context, index) {
        final row = rows[index];
        return KeyedSubtree(
          key: ValueKey(row.id),
          child: switch (row) {
            YearRow() => _YearHeader(row.year),
            MonthRow() => _MonthHeader(row),
            DayRow() => _DayRowView(row: row),
            UndatedRow() => const _UndatedRowView(),
          },
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.row);

  final MonthRow row;

  @override
  Widget build(BuildContext context) {
    final title = row.key.isUndated
        ? 'Sin fecha'
        : EsDateFormat.month(row.key.month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          '$title · ${row.count}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

/// Un día: pide sus momentos al aparecer. Mientras carga reserva la altura que
/// tuvo la última vez (o una estimada), para que la lista no salte.
class _DayRowView extends ConsumerWidget {
  const _DayRowView({required this.row});

  final DayRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.read(dayHeightCacheProvider);
    final days = ref.watch(dayMomentsProvider(row.date));

    return days.when(
      loading: () => SizedBox(
        height:
            cache[row.date] ??
            _estimatedDayHeight(MediaQuery.sizeOf(context).width, row.count),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(userMessageFor(error)),
      ),
      data: (days) {
        if (days.isEmpty) return const SizedBox.shrink();
        return _RememberHeight(
          onHeight: (height) => cache[row.date] = height,
          child: _DaySection(day: days.first),
        );
      },
    );
  }
}

class _UndatedRowView extends ConsumerWidget {
  const _UndatedRowView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(undatedDaysProvider);
    return days.when(
      loading: () => const SizedBox(height: 160),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(userMessageFor(error)),
      ),
      data: (days) =>
          days.isEmpty ? const SizedBox.shrink() : _DaySection(day: days.first),
    );
  }
}

/// Informa la altura que alcanzó el hijo tras dibujarse.
class _RememberHeight extends StatefulWidget {
  const _RememberHeight({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_RememberHeight> createState() => _RememberHeightState();
}

class _RememberHeightState extends State<_RememberHeight> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
    });
    return widget.child;
  }
}

/// Altura aproximada de un día con un solo momento, para reservar espacio
/// antes de conocer su contenido real.
double _estimatedDayHeight(double screenWidth, int count) {
  const columns = 4;
  const spacing = 4.0;
  const horizontalPadding = 32.0;
  const chrome = 12 + 20 + 8 + 22; // relleno + día + relleno + etiqueta
  final tile =
      (screenWidth - horizontalPadding - spacing * (columns - 1)) / columns;
  final tiles = count < 8 ? count : 8;
  final rows = (tiles / columns).ceil();
  return chrome + rows * tile + (rows - 1) * spacing;
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
