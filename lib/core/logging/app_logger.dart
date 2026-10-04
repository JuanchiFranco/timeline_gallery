import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Áreas del sistema que registran logs. Permiten filtrar en DevTools.
enum LogTag { gallerySync, galleryRepository, database, platform, ui }

enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);

  /// Valor numérico compatible con `dart:developer` (`package:logging`).
  final int value;
}

@immutable
class LogRecord {
  const LogRecord({
    required this.tag,
    required this.level,
    required this.message,
    this.errorType,
    this.stackTrace,
  });

  final LogTag tag;
  final LogLevel level;
  final String message;

  /// Solo el *tipo* del error, nunca su contenido: el texto de una excepción
  /// puede incluir rutas, nombres de archivo o ubicaciones del usuario.
  final String? errorType;
  final StackTrace? stackTrace;
}

typedef LogSink = void Function(LogRecord record);

/// Logger estructurado para desarrollo.
///
/// Reglas de privacidad: no pasar rutas, nombres de archivo, coordenadas ni
/// ningún dato del contenido multimedia en [message]. Solo identificadores
/// opacos y contadores.
///
/// Con `enabled: false` (producción) no produce ninguna salida.
class AppLogger {
  AppLogger({required this.enabled, LogSink? sink})
    : _sink = sink ?? _developerLogSink;

  final bool enabled;
  final LogSink _sink;

  void debug(LogTag tag, String message) =>
      _write(tag, LogLevel.debug, message);

  void info(LogTag tag, String message) => _write(tag, LogLevel.info, message);

  void warning(LogTag tag, String message, {Object? error}) =>
      _write(tag, LogLevel.warning, message, error: error);

  void error(
    LogTag tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _write(
    tag,
    LogLevel.error,
    message,
    error: error,
    stackTrace: stackTrace,
  );

  void _write(
    LogTag tag,
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    _sink(
      LogRecord(
        tag: tag,
        level: level,
        message: message,
        errorType: error?.runtimeType.toString(),
        stackTrace: stackTrace,
      ),
    );
  }
}

void _developerLogSink(LogRecord record) {
  developer.log(
    record.errorType == null
        ? record.message
        : '${record.message} (${record.errorType})',
    name: record.tag.name,
    level: record.level.value,
    stackTrace: record.stackTrace,
  );
}
