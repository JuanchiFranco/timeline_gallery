import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';

/// Registra los errores que nadie capturó, en vez de perderlos.
///
/// * `FlutterError.onError`: errores del framework (build, layout, gestos).
/// * `PlatformDispatcher.onError`: errores asíncronos fuera de cualquier
///   `try/catch` (futures sin `await`, streams sin `onError`).
///
/// Solo se registra el *tipo* del error (regla del [AppLogger]): el texto de
/// una excepción puede incluir rutas o nombres de archivo del usuario.
///
/// Con [replaceErrorWidget] los errores de construcción de un widget muestran
/// un aviso discreto en lugar de la pantalla roja/gris del framework, que en
/// producción sería una pantalla en blanco sin explicación.
void installGlobalErrorHandlers(
  AppLogger logger, {
  bool replaceErrorWidget = false,
  ui.PlatformDispatcher? dispatcher,
}) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      LogTag.ui,
      'uncaught framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    // Conserva el comportamiento por defecto (consola en debug).
    (previous ?? FlutterError.presentError)(details);
  };

  (dispatcher ?? ui.PlatformDispatcher.instance).onError = (error, stack) {
    logger.error(
      LogTag.ui,
      'uncaught async error',
      error: error,
      stackTrace: stack,
    );
    // `true`: el error se considera manejado y no tumba la app.
    return true;
  };

  if (replaceErrorWidget) {
    ErrorWidget.builder = (details) => const FallbackErrorWidget();
  }
}

/// Lo que se ve en lugar de un widget que falló al construirse.
class FallbackErrorWidget extends StatelessWidget {
  const FallbackErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Puede aparecer en cualquier punto del árbol, incluso sin `Theme` ni
    // `Directionality` por encima: no depende de ninguno.
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No pudimos mostrar esto',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF757575), fontSize: 14),
          ),
        ),
      ),
    );
  }
}
