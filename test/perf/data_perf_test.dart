@Tags(['perf'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/data/drift_sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/services/gallery_sync_service.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_grouping.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_rows.dart';

import 'perf_data.dart';

/// Mide la capa de datos con ~50 000 assets. Los tiempos son de esta máquina
/// (en un teléfono serán varias veces mayores): sirven para comparar antes y
/// después de un cambio, y los límites del `expect` solo atrapan regresiones
/// catastróficas.
///
///   flutter test --run-skipped --tags perf test/perf/data_perf_test.dart
void main() {
  late SyntheticGallery gallery;
  late AppDatabase db;
  late DriftMediaIndexRepository index;
  late DriftSyncStateStore state;

  setUpAll(() {
    gallery = SyntheticGallery();
    // ignore: avoid_print
    print('PERF assets=${gallery.assets.length}');
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final logger = AppLogger(enabled: false);
    index = DriftMediaIndexRepository(db, logger);
    state = DriftSyncStateStore(db, logger);
  });

  tearDown(() => db.close());

  Future<T> timed<T>(String label, Future<T> Function() body) async {
    final watch = Stopwatch()..start();
    final result = await body();
    // ignore: avoid_print
    print('PERF ${label.padRight(44)} ${watch.elapsedMilliseconds} ms');
    return result;
  }

  Future<void> fullSync() async {
    final service = DefaultGallerySyncService(
      device: PresortedDevice(gallery.assets),
      index: index,
      state: state,
      logger: AppLogger(enabled: false),
    );
    await service.sync();
  }

  test('sincronización completa inicial', () async {
    final watch = Stopwatch()..start();
    await timed<void>('full sync (${gallery.assets.length} assets)', fullSync);
    expect(await index.count(), gallery.assets.length);
    expect(watch.elapsed.inSeconds, lessThan(120));
  });

  test('consultas sobre un índice grande', () async {
    await fullSync();

    await timed<int>('count', index.count);
    await timed<Set<String>>('knownPlatformIds', index.knownPlatformIds);

    final days = await timed<List<DayBucket>>(
      'watchDayBuckets (primera emisión)',
      () => index.watchDayBuckets().first,
    );
    final months = await timed<List<MonthBucket>>(
      'monthBucketsFrom (${days.length} días)',
      () async => monthBucketsFrom(days),
    );
    await timed<List<TimelineRow>>(
      'buildTimelineRows (${days.length} días)',
      () async => buildTimelineRows(days),
    );
    // ignore: avoid_print
    print('PERF   días=${days.length} meses=${months.length}');
    expect(days, isNotEmpty);

    final heavyKey = MonthKey(
      gallery.heavyMonth.year,
      gallery.heavyMonth.month,
    );
    final heavyDay = DateTime(heavyKey.year, heavyKey.month, 10);
    final oneDay = await timed<List<MediaAsset>>(
      'inRange un día del mes pesado',
      () => index.inRange(
        fromInclusive: heavyDay.toUtc(),
        toExclusive: DateTime(heavyDay.year, heavyDay.month, 11).toUtc(),
      ),
    );
    await timed<List<TimelineDay>>(
      'groupIntoDays ese día (${oneDay.length} assets)',
      () async => groupIntoDays(oneDay),
    );

    // El mes pesado completo, que ya no se carga de una vez en la UI.
    final heavyAssets = await timed<List<MediaAsset>>(
      'inRange mes pesado (referencia)',
      () => index.inRange(
        fromInclusive: heavyKey.startUtc,
        toExclusive: heavyKey.endUtc,
      ),
    );
    // ignore: avoid_print
    print('PERF   assets del mes pesado=${heavyAssets.length}');
  });

  test('sincronización incremental sin cambios y con una foto nueva', () async {
    await fullSync();
    final service = DefaultGallerySyncService(
      device: PresortedDevice(gallery.assets),
      index: index,
      state: state,
      logger: AppLogger(enabled: false),
    );

    final result = await timed<SyncResult>(
      'incremental sin cambios',
      service.sync,
    );
    expect(result.hasChanges, isFalse);
  });

  test('re-sincronización completa (todo ya indexado)', () async {
    await fullSync();
    final service = DefaultGallerySyncService(
      device: PresortedDevice(gallery.assets),
      index: index,
      state: state,
      logger: AppLogger(enabled: false),
    );

    await timed(
      'forceFull sobre índice lleno',
      () => service.sync(forceFull: true),
    );
  });
}
