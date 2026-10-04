import 'package:flutter/material.dart';
import 'package:galeria_eventos/core/widgets/state_message.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';

/// Explica por qué se pide acceso y ofrece la acción que corresponde al
/// estado: pedir el permiso, ir a los ajustes o, si está bloqueado por el
/// sistema, solo informar.
class PermissionPrompt extends StatelessWidget {
  const PermissionPrompt({
    required this.permission,
    required this.onRequest,
    required this.onOpenSettings,
    super.key,
  });

  final GalleryPermission permission;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return switch (permission) {
      GalleryPermission.notDetermined => StateMessage(
        icon: Icons.photo_library_outlined,
        title: 'Tus recuerdos, en una línea de tiempo',
        message:
            'Para organizar tus fotos y videos necesitamos acceder a tu '
            'galería. Todo se queda en este dispositivo.',
        action: FilledButton(
          onPressed: onRequest,
          child: const Text('Conceder acceso'),
        ),
      ),
      GalleryPermission.denied => StateMessage(
        icon: Icons.lock_outline,
        title: 'Sin acceso a tu galería',
        message:
            'Activa el permiso de fotos y videos en los ajustes del '
            'dispositivo para ver tus recuerdos.',
        action: FilledButton(
          onPressed: onOpenSettings,
          child: const Text('Abrir ajustes'),
        ),
      ),
      GalleryPermission.restricted => const StateMessage(
        icon: Icons.block,
        title: 'Acceso restringido',
        message:
            'Este dispositivo no permite que la app acceda a la galería '
            '(control parental o políticas del sistema).',
      ),
      // Quien llama solo construye este widget cuando no se puede leer.
      GalleryPermission.granted ||
      GalleryPermission.limited => const SizedBox.shrink(),
    };
  }
}

/// Aviso cuando el usuario concedió solo algunos elementos.
class LimitedAccessBanner extends StatelessWidget {
  const LimitedAccessBanner({required this.onManage, super.key});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text(
        'Solo ves los elementos que elegiste. Amplía la selección para '
        'completar tu línea de tiempo.',
      ),
      leading: const Icon(Icons.info_outline),
      actions: [TextButton(onPressed: onManage, child: const Text('Ajustar'))],
    );
  }
}
