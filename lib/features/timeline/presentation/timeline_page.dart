import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/widgets/error_state.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_permission_controller.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/sync_controller.dart';
import 'package:galeria_eventos/features/gallery/presentation/widgets/permission_prompt.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/timeline_view.dart';

/// Pantalla principal. Resuelve el permiso de galería y los estados base
/// (cargando / error / vacío) antes de mostrar la línea de tiempo.
class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(galleryPermissionProvider);
    final controller = ref.read(galleryPermissionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tus recuerdos')),
      body: permission.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(galleryPermissionProvider),
        ),
        data: (value) => value.canRead
            ? _IndexedMemories(
                limited: value == GalleryPermission.limited,
                onManageLimited: () async {
                  await controller.manageLimitedSelection();
                  await ref.read(syncControllerProvider.notifier).sync();
                },
              )
            : PermissionPrompt(
                permission: value,
                onRequest: controller.request,
                onOpenSettings: controller.openSettings,
              ),
      ),
    );
  }
}

class _IndexedMemories extends ConsumerWidget {
  const _IndexedMemories({
    required this.limited,
    required this.onManageLimited,
  });

  final bool limited;
  final VoidCallback onManageLimited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(timelineRowsProvider);
    final sync = ref.watch(syncControllerProvider);

    return Column(
      children: [
        if (sync.isRunning) LinearProgressIndicator(value: sync.progress),
        if (sync.failure case final failure?)
          MaterialBanner(
            content: Text(failure.userMessage),
            leading: const Icon(Icons.sync_problem),
            actions: [
              TextButton(
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).sync(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        if (limited) LimitedAccessBanner(onManage: onManageLimited),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(dayBucketsProvider),
            ),
            data: (rows) => rows.isEmpty
                ? StateMessage(
                    icon: Icons.photo_library_outlined,
                    title: sync.isRunning
                        ? 'Preparando tus recuerdos'
                        : 'Aún no hay recuerdos para mostrar',
                    message: sync.isRunning
                        ? 'Estamos leyendo tu galería. Puede tardar un poco '
                              'la primera vez.'
                        : 'No encontramos fotos ni videos en tu galería.',
                  )
                : TimelineView(rows: rows),
          ),
        ),
      ],
    );
  }
}
