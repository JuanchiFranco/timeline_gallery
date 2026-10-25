import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/app/app.dart';
import 'package:galeria_eventos/core/di/core_providers.dart';
import 'package:galeria_eventos/core/error/global_error_handlers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // El contenedor se crea aquí (y no dentro de `ProviderScope`) para poder
  // instalar los manejadores de errores antes de construir la UI.
  final container = ProviderContainer();
  installGlobalErrorHandlers(
    container.read(appLoggerProvider),
    replaceErrorWidget: kReleaseMode,
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const GaleriaApp()),
  );
}
