import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/config/app_config.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';

/// Providers de infraestructura compartida. Los tests los reemplazan con
/// `overrideWith`, así ninguna clase construye sus propias dependencias.

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final appLoggerProvider = Provider<AppLogger>(
  (ref) => AppLogger(enabled: ref.watch(appConfigProvider).loggingEnabled),
);

/// Base de datos del índice. `driftDatabase` la abre en un isolate de fondo,
/// así las consultas pesadas no bloquean el hilo de la UI.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(driftDatabase(name: 'galeria_index'));
  ref.onDispose(database.close);
  return database;
});
