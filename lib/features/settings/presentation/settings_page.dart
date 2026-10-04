import 'package:flutter/material.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';

/// Placeholder: permisos, sincronización y privacidad llegan en fases
/// posteriores.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: const StateMessage(
        icon: Icons.lock_outline,
        title: '100% local',
        message:
            'Tus fotos y videos nunca salen de este dispositivo. '
            'No subimos nada a ningún servidor.',
      ),
    );
  }
}
