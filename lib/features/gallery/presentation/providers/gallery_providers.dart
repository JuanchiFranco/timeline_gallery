import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/di/core_providers.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/data/drift_sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_permission_service.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_thumbnail_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/gallery_permission_service.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/thumbnail_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/services/gallery_sync_service.dart';

final mediaIndexRepositoryProvider = Provider<MediaIndexRepository>(
  (ref) => DriftMediaIndexRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appLoggerProvider),
  ),
);

final syncStateStoreProvider = Provider<SyncStateStore>(
  (ref) => DriftSyncStateStore(
    ref.watch(appDatabaseProvider),
    ref.watch(appLoggerProvider),
  ),
);

final galleryPermissionServiceProvider = Provider<GalleryPermissionService>(
  (ref) => PhotoManagerPermissionService(ref.watch(appLoggerProvider)),
);

final deviceGalleryRepositoryProvider = Provider<DeviceGalleryRepository>(
  (ref) => PhotoManagerGalleryRepository(
    ref.watch(galleryPermissionServiceProvider),
    ref.watch(appLoggerProvider),
  ),
);

final gallerySyncServiceProvider = Provider<GallerySyncService>(
  (ref) => DefaultGallerySyncService(
    device: ref.watch(deviceGalleryRepositoryProvider),
    index: ref.watch(mediaIndexRepositoryProvider),
    state: ref.watch(syncStateStoreProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final thumbnailRepositoryProvider = Provider<ThumbnailRepository>(
  (ref) => PhotoManagerThumbnailRepository(ref.watch(appLoggerProvider)),
);
