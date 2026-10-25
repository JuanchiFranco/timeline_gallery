import 'package:flutter/material.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';

/// Pantalla de error con el mensaje para el usuario y, si hay [onRetry], un
/// botón para volver a intentar (sin él, un error transitorio dejaría la
/// pantalla atascada hasta reiniciar la app).
class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: Icons.error_outline,
      title: 'Algo salió mal',
      message: userMessageFor(error),
      action: onRetry == null
          ? null
          : FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
    );
  }
}
