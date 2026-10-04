import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';
import 'package:galeria_eventos/features/calendar/domain/calendar.dart';
import 'package:galeria_eventos/features/calendar/presentation/widgets/calendar_month_grid.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:go_router/go_router.dart';

/// Calendario mensual: una página por mes, desde el más antiguo hasta el más
/// reciente con recuerdos. Tocar un día con recuerdos abre su detalle.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = ref.watch(monthBucketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: buckets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.error_outline,
          title: 'Algo salió mal',
          message: switch (error) {
            final AppFailure failure => failure.userMessage,
            _ => const UnexpectedFailure('unclassified').userMessage,
          },
        ),
        data: (buckets) {
          final months = calendarMonths(buckets);
          if (months.isEmpty) {
            return const StateMessage(
              icon: Icons.calendar_month_outlined,
              title: 'Tu calendario de recuerdos',
              message: 'Aquí verás qué días tienen fotos y videos.',
            );
          }
          return _CalendarBody(months: months);
        },
      ),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  const _CalendarBody({required this.months});

  final List<MonthKey> months;

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  late final PageController _controller;
  late MonthKey _current;

  @override
  void initState() {
    super.initState();
    _current = widget.months.last;
    _controller = PageController(initialPage: widget.months.length - 1);
  }

  @override
  void didUpdateWidget(_CalendarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La sincronización puede agregar meses antiguos y correr todos los
    // índices: se vuelve a la página del mes que se estaba viendo.
    final index = widget.months.indexOf(_current);
    if (index >= 0 && index != oldWidget.months.indexOf(_current)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _index => widget.months.indexOf(_current);

  void _goTo(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = widget.months;
    final now = DateTime.now();
    final thisMonth = MonthKey(now.year, now.month);
    final todayIndex = months.indexOf(thisMonth);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    '${EsDateFormat.month(_current.month)} ${_current.year}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: _index < months.length - 1
                    ? () => _goTo(_index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        if (todayIndex >= 0 && _current != thisMonth)
          TextButton(
            onPressed: () => _goTo(todayIndex),
            child: const Text('Ir a hoy'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              for (final label in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: months.length,
            onPageChanged: (index) => setState(() => _current = months[index]),
            itemBuilder: (context, index) => CalendarMonthGrid(
              month: months[index],
              onOpenDay: (date) => context.push(dayLocation(date)),
            ),
          ),
        ),
      ],
    );
  }
}
