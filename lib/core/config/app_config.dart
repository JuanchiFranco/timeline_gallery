import 'package:flutter/foundation.dart';

/// Configuración de compilación/ejecución. Se inyecta con
/// `--dart-define` o `--dart-define-from-file=.env` (ver `.env.example`).
///
/// No hay secretos: la app es 100% local y no habla con ningún servidor.
@immutable
class AppConfig {
  const AppConfig({required this.loggingEnabled, required this.syncBatchSize});

  /// Valores por defecto leídos del entorno de compilación.
  factory AppConfig.fromEnvironment() => const AppConfig(
    loggingEnabled: bool.fromEnvironment(
      'ENABLE_LOGS',
      defaultValue: kDebugMode,
    ),
    syncBatchSize: int.fromEnvironment('SYNC_BATCH_SIZE', defaultValue: 500),
  );

  final bool loggingEnabled;

  /// Tamaño de lote para la sincronización con la galería.
  final int syncBatchSize;
}
