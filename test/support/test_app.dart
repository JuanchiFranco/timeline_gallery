import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:galeria_eventos/app/app.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/settings/presentation/providers/settings_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fakes.dart';
import 'fixtures.dart';

/// [count] assets el 23 de septiembre de 2026 (hora local), uno cada 5 minutos
/// desde las 08:00, así que forman un solo momento.
List<MediaAsset> september(int count) => [
  for (var i = 0; i < count; i++)
    buildAsset(
      'p$i',
      captureDate: DateTime(2026, 9, 23, 8, i * 5).toUtc(),
      type: i == 0 ? MediaType.video : MediaType.image,
    ),
];

/// La app con la plataforma simulada. Los resúmenes por día (que alimentan el
/// timeline y el calendario) se derivan de [assets]; pasar [dayBuckets] los
/// reemplaza, para probar los estados de carga y de error.
Widget testApp({
  List<MediaAsset> assets = const [],
  Stream<List<DayBucket>>? dayBuckets,
  FakeGalleryPermissionService? permissions,
  FakeGallerySyncService? sync,
  FakeMediaFileRepository? mediaFiles,
  MediaIndexRepository? index,
  FakeSyncStateStore? syncState,
  PackageInfo? packageInfo,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    // Sin reintentos automáticos: los tests de error deben ser deterministas.
    retry: (retryCount, error) => null,
    overrides: [
      if (dayBuckets != null)
        dayBucketsProvider.overrideWith((ref) => dayBuckets),
      mediaIndexRepositoryProvider.overrideWithValue(
        index ?? FakeMediaIndexRepository(assets),
      ),
      thumbnailRepositoryProvider.overrideWithValue(FakeThumbnailRepository()),
      mediaFileRepositoryProvider.overrideWithValue(
        mediaFiles ?? FakeMediaFileRepository(),
      ),
      galleryPermissionServiceProvider.overrideWithValue(
        permissions ?? FakeGalleryPermissionService(GalleryPermission.granted),
      ),
      gallerySyncServiceProvider.overrideWithValue(
        sync ?? FakeGallerySyncService(),
      ),
      syncStateStoreProvider.overrideWithValue(
        syncState ?? FakeSyncStateStore(),
      ),
      packageInfoProvider.overrideWith(
        (ref) =>
            packageInfo ??
            PackageInfo(
              appName: 'galeria_eventos',
              packageName: 'test.galeria_eventos',
              version: '1.0.0',
              buildNumber: '1',
            ),
      ),
      ...overrides,
    ],
    child: const GaleriaApp(),
  );
}
