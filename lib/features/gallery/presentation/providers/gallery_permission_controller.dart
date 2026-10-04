import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';

/// Estado del permiso de galería para la UI.
///
/// Se vuelve a consultar al volver a la app (el usuario pudo cambiarlo desde
/// los ajustes del sistema).
class GalleryPermissionController extends AsyncNotifier<GalleryPermission> {
  @override
  Future<GalleryPermission> build() {
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(lifecycle.dispose);
    return ref.read(galleryPermissionServiceProvider).status();
  }

  /// Muestra el diálogo del sistema (solo si el permiso aún no se decidió).
  Future<void> request() async {
    final service = ref.read(galleryPermissionServiceProvider);
    state = await AsyncValue.guard(service.request);
  }

  /// Relee el estado sin pasar por `loading`, para no parpadear la pantalla.
  Future<void> refresh() async {
    final service = ref.read(galleryPermissionServiceProvider);
    final next = await AsyncValue.guard(service.status);
    if (ref.mounted && next != state) state = next;
  }

  Future<void> openSettings() =>
      ref.read(galleryPermissionServiceProvider).openSystemSettings();

  Future<void> manageLimitedSelection() async {
    await ref.read(galleryPermissionServiceProvider).manageLimitedSelection();
    await refresh();
  }
}

final galleryPermissionProvider =
    AsyncNotifierProvider<GalleryPermissionController, GalleryPermission>(
      GalleryPermissionController.new,
    );
