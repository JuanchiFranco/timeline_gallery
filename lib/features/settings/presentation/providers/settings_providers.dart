import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/sync_controller.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión de la app instalada. Los tests lo reemplazan.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Cuándo terminó la última sincronización, o `null` si nunca terminó una.
/// Se vuelve a leer cada vez que una sincronización empieza o termina.
final lastSyncProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  ref.watch(syncControllerProvider.select((status) => status.isRunning));
  final raw = await ref
      .watch(syncStateStoreProvider)
      .read(SyncStateKey.lastIncrementalSyncAt);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
});

/// Cuántos recuerdos hay indexados, sumando los resúmenes por día.
final indexedCountProvider = Provider<int?>(
  (ref) => ref
      .watch(dayBucketsProvider)
      .whenData((days) => days.fold<int>(0, (sum, day) => sum + day.count))
      .value,
);
