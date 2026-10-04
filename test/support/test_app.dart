import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/app/app.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';

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

Stream<List<MonthBucket>> septemberBuckets(int count) =>
    Stream.value([MonthBucket(const MonthKey(2026, 9), count)]);

Widget testApp({
  required Stream<List<MonthBucket>> months,
  List<MediaAsset> assets = const [],
  FakeGalleryPermissionService? permissions,
  FakeGallerySyncService? sync,
  FakeMediaFileRepository? mediaFiles,
}) {
  return ProviderScope(
    // Sin reintentos automáticos: los tests de error deben ser deterministas.
    retry: (retryCount, error) => null,
    overrides: [
      monthBucketsProvider.overrideWith((ref) => months),
      mediaIndexRepositoryProvider.overrideWithValue(
        FakeMediaIndexRepository(assets),
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
    ],
    child: const GaleriaApp(),
  );
}
