import 'package:flutter/material.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';

/// Placeholder: el calendario real llega en la Fase 6.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: const StateMessage(
        icon: Icons.calendar_month_outlined,
        title: 'Tu calendario de recuerdos',
        message: 'Aquí verás qué días tienen fotos y videos.',
      ),
    );
  }
}
