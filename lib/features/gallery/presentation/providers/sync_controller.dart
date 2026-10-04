import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_permission_controller.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';

/// Estado de la sincronización para la UI.
@immutable
class SyncStatus {
  const SyncStatus.idle()
    : isRunning = false,
      processed = 0,
      total = 0,
      failure = null;

  const SyncStatus.running({this.processed = 0, this.total = 0})
    : isRunning = true,
      failure = null;

  const SyncStatus.failed(AppFailure this.failure)
    : isRunning = false,
      processed = 0,
      total = 0;

  final bool isRunning;
  final int processed;
  final int total;
  final AppFailure? failure;

  /// Avance de 0 a 1, o `null` si aún no se conoce el total.
  double? get progress => isRunning && total > 0
      ? (processed / total).clamp(0, 1).toDouble()
      : null;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      isRunning == other.isRunning &&
      processed == other.processed &&
      total == other.total &&
      failure == other.failure;

  @override
  int get hashCode => Object.hash(isRunning, processed, total, failure);
}

/// Dispara la sincronización cuando hay permiso de lectura y al volver a la
/// app, y expone su avance.
class SyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    ref.listen(galleryPermissionProvider, (previous, next) {
      final canRead = next.value?.canRead ?? false;
      final couldRead = previous?.value?.canRead ?? false;
      if (canRead && !couldRead) _syncSoon();
    }, fireImmediately: true);

    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(galleryPermissionProvider).value?.canRead ?? false) {
          _syncSoon();
        }
      },
    );
    ref.onDispose(lifecycle.dispose);

    return const SyncStatus.idle();
  }

  /// `build` no puede modificar el estado: se difiere al siguiente microtask.
  void _syncSoon() => unawaited(Future.microtask(sync));

  Future<void> sync({bool forceFull = false}) async {
    if (state.isRunning) return;
    state = const SyncStatus.running();
    try {
      await ref
          .read(gallerySyncServiceProvider)
          .sync(
            forceFull: forceFull,
            onProgress: (processed, total) {
              if (ref.mounted) {
                state = SyncStatus.running(processed: processed, total: total);
              }
            },
          );
      if (ref.mounted) state = const SyncStatus.idle();
    } on Object catch (error, stackTrace) {
      if (ref.mounted) {
        state = SyncStatus.failed(asAppFailure(error, stackTrace));
      }
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
