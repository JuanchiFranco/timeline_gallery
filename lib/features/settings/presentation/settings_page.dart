import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/config/app_info.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_permission_controller.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/sync_controller.dart';
import 'package:galeria_eventos/features/settings/presentation/providers/settings_providers.dart';

/// Ajustes: acceso a la galería, estado de la sincronización, qué guarda la app
/// y datos de la versión.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          _SectionTitle('Acceso a la galería'),
          _PermissionSection(),
          _SectionTitle('Sincronización'),
          _SyncSection(),
          _SectionTitle('Privacidad'),
          _PrivacySection(),
          _SectionTitle('Acerca de'),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _PermissionSection extends ConsumerWidget {
  const _PermissionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(galleryPermissionProvider);
    final controller = ref.read(galleryPermissionProvider.notifier);

    return permission.when(
      loading: () => const ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Comprobando el acceso…'),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('No pudimos comprobar el acceso'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(galleryPermissionProvider),
          child: const Text('Reintentar'),
        ),
      ),
      data: (value) {
        final (icon, title, detail) = switch (value) {
          GalleryPermission.granted => (
            Icons.check_circle_outline,
            'Acceso completo',
            'La app puede mostrar todas tus fotos y videos.',
          ),
          GalleryPermission.limited => (
            Icons.info_outline,
            'Acceso limitado',
            'Solo ves los elementos que elegiste.',
          ),
          GalleryPermission.denied => (
            Icons.lock_outline,
            'Sin acceso',
            'Actívalo en los ajustes del dispositivo para ver tus recuerdos.',
          ),
          GalleryPermission.notDetermined => (
            Icons.photo_library_outlined,
            'Aún no concedido',
            'Necesitamos acceder a tu galería para organizar tus recuerdos.',
          ),
          GalleryPermission.restricted => (
            Icons.block,
            'Acceso restringido',
            'El dispositivo no permite que la app acceda a la galería.',
          ),
        };
        return Column(
          children: [
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(detail),
            ),
            if (value.canRequest)
              _ActionRow(
                label: 'Conceder acceso',
                onPressed: controller.request,
              ),
            if (value == GalleryPermission.limited)
              _ActionRow(
                label: 'Elegir más elementos',
                onPressed: controller.manageLimitedSelection,
              ),
            if (value != GalleryPermission.granted &&
                value != GalleryPermission.restricted &&
                !value.canRequest)
              _ActionRow(
                label: 'Abrir ajustes del dispositivo',
                onPressed: controller.openSettings,
              ),
          ],
        );
      },
    );
  }
}

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final count = ref.watch(indexedCountProvider);
    final lastSync = ref.watch(lastSyncProvider).value;
    final canRead =
        ref.watch(galleryPermissionProvider).value?.canRead ?? false;

    final String title;
    if (sync.isRunning) {
      title = 'Sincronizando…';
    } else if (sync.failure != null) {
      title = sync.failure!.userMessage;
    } else {
      title = 'Al día';
    }

    final details = [
      if (count != null)
        count == 1 ? '1 recuerdo indexado' : '$count recuerdos indexados',
      if (lastSync != null) 'Última vez: ${_describe(lastSync)}',
    ];

    return Column(
      children: [
        ListTile(
          leading: Icon(sync.failure != null ? Icons.sync_problem : Icons.sync),
          title: Text(title),
          subtitle: details.isEmpty ? null : Text(details.join('\n')),
          isThreeLine: details.length > 1,
        ),
        if (sync.isRunning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(value: sync.progress),
          ),
        _ActionRow(
          label: 'Volver a escanear la galería',
          onPressed: canRead && !sync.isRunning
              ? () => ref
                    .read(syncControllerProvider.notifier)
                    .sync(forceFull: true)
              : null,
        ),
      ],
    );
  }

  static String _describe(DateTime when) {
    final now = DateTime.now();
    return '${EsDateFormat.day(when, today: now)}, '
        '${EsDateFormat.timeRange(when, when)}';
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('100% local'),
          subtitle: Text(
            'Tus fotos y videos nunca salen de este dispositivo. La app no '
            'tiene cuentas, ni servidores, ni analíticas, y no se conecta a '
            'Internet.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.storage_outlined),
          title: Text('Qué guarda la app'),
          subtitle: Text(
            'Solo un índice de datos de cada foto o video (fecha, tamaño y '
            'tipo) para armar la línea de tiempo. Tus archivos se leen '
            'directamente de la galería y no se copian.',
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final version = info == null
        ? null
        : '${info.version} (${info.buildNumber})';

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text(appName),
          subtitle: version == null ? null : Text('Versión $version'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Licencias de código abierto'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: appName,
            applicationVersion: version,
          ),
        ),
      ],
    );
  }
}

/// Botón alineado a la izquierda bajo una fila de información.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
