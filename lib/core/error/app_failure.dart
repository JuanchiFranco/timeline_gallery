import 'package:flutter/foundation.dart';

/// Error de dominio. Es lo único que cruza hacia la capa de presentación:
/// los errores de plataforma o de base de datos se traducen a un
/// [AppFailure] en el límite de la capa de datos.
///
/// [message] es para desarrolladores y nunca debe contener rutas, nombres de
/// archivo ni ubicaciones. [userMessage] es lo que ve el usuario.
@immutable
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause, this.stackTrace});

  final String message;

  /// Error original. Se conserva para depuración, pero no se muestra ni se
  /// imprime con `toString()` (podría incluir datos personales).
  final Object? cause;
  final StackTrace? stackTrace;

  String get userMessage;

  @override
  String toString() => '$runtimeType: $message';
}

/// El usuario no concedió (o revocó) el acceso a la galería.
final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.cause, super.stackTrace});

  @override
  String get userMessage =>
      'Necesitamos acceso a tu galería para mostrar tus recuerdos.';
}

/// Falló la lectura de la galería del dispositivo (adaptador de plataforma).
final class GalleryFailure extends AppFailure {
  const GalleryFailure(super.message, {super.cause, super.stackTrace});

  @override
  String get userMessage => 'No pudimos leer tu galería. Inténtalo de nuevo.';
}

/// Falló el índice local (base de datos).
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause, super.stackTrace});

  @override
  String get userMessage =>
      'No pudimos guardar tus recuerdos en el dispositivo. '
      'Revisa que tengas espacio disponible.';
}

/// Falló o se interrumpió la sincronización.
final class SyncFailure extends AppFailure {
  const SyncFailure(super.message, {super.cause, super.stackTrace});

  @override
  String get userMessage =>
      'La sincronización se interrumpió. Retomaremos donde quedó.';
}

/// Error no clasificado. Debe ser la excepción, no la regla: cada vez que
/// aparezca en logs es una señal de que falta una clasificación.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});

  @override
  String get userMessage => 'Algo salió mal. Inténtalo de nuevo.';
}

/// Convierte cualquier error en un [AppFailure] sin perder el original.
AppFailure asAppFailure(Object error, StackTrace stackTrace) {
  if (error is AppFailure) return error;
  return UnexpectedFailure(
    'Unclassified ${error.runtimeType}',
    cause: error,
    stackTrace: stackTrace,
  );
}
