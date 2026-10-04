import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';
import 'package:galeria_eventos/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/moment_block.dart';

/// Todos los recuerdos de un día, agrupados por momento.
class DayPage extends ConsumerWidget {
  const DayPage({required this.date, super.key});

  /// Medianoche local del día a mostrar.
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(dayMomentsProvider(date));

    return Scaffold(
      appBar: AppBar(
        title: Text(EsDateFormat.day(date, today: DateTime.now())),
      ),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.error_outline,
          title: 'Algo salió mal',
          message: switch (error) {
            final AppFailure failure => failure.userMessage,
            _ => const UnexpectedFailure('unclassified').userMessage,
          },
        ),
        data: (days) {
          final moments = [for (final day in days) ...day.moments];
          if (moments.isEmpty) {
            return const StateMessage(
              icon: Icons.photo_library_outlined,
              title: 'Sin recuerdos este día',
            );
          }
          return CustomScrollView(
            slivers: [
              for (final moment in moments)
                MomentSliver(moment: moment, showTime: true),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

/// Pantalla para una ruta de día con una fecha que no existe.
class InvalidDayPage extends StatelessWidget {
  const InvalidDayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const StateMessage(
        icon: Icons.event_busy_outlined,
        title: 'Esa fecha no es válida',
      ),
    );
  }
}
