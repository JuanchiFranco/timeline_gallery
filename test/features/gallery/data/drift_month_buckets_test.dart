import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

import '../../../support/fixtures.dart';

/// Capturado en la hora local indicada (los tests no dependen de la zona
/// horaria de la máquina).
MediaAsset _local(String id, int year, int month, int day, [int hour = 12]) =>
    buildAsset(id, captureDate: DateTime(year, month, day, hour).toUtc());

void main() {
  late AppDatabase db;
  late DriftMediaIndexRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftMediaIndexRepository(db, AppLogger(enabled: false));
  });

  tearDown(() => db.close());

  test('sin assets no hay meses', () async {
    expect(await repository.watchMonthBuckets().first, isEmpty);
  });

  test('cuenta por mes local, del más reciente al más antiguo', () async {
    await repository.upsertAll([
      _local('a', 2025, 12, 31),
      _local('b', 2026, 9, 1),
      _local('c', 2026, 9, 23),
      _local('d', 2026, 10, 2),
    ]);

    final buckets = await repository.watchMonthBuckets().first;

    expect(buckets, const [
      MonthBucket(MonthKey(2026, 10), 1),
      MonthBucket(MonthKey(2026, 9), 2),
      MonthBucket(MonthKey(2025, 12), 1),
    ]);
  });

  test('los límites del mes usan hora local, no UTC', () async {
    // Primer y último instante del mes local: deben caer ambos en septiembre.
    await repository.upsertAll([
      buildAsset('first', captureDate: DateTime(2026, 9).toUtc()),
      buildAsset('last', captureDate: DateTime(2026, 9, 30, 23, 59).toUtc()),
    ]);

    final buckets = await repository.watchMonthBuckets().first;

    expect(buckets, const [MonthBucket(MonthKey(2026, 9), 2)]);
  });

  test('el rango de MonthKey coincide con lo que cuenta el bucket', () async {
    await repository.upsertAll([
      _local('in1', 2026, 9, 1, 0),
      _local('in2', 2026, 9, 30, 23),
      _local('out1', 2026, 8, 31, 23),
      _local('out2', 2026, 10, 1, 0),
    ]);
    const key = MonthKey(2026, 9);

    final inRange = await repository.inRange(
      fromInclusive: key.startUtc,
      toExclusive: key.endUtc,
    );
    final bucket = (await repository.watchMonthBuckets().first).firstWhere(
      (b) => b.key == key,
    );

    expect(inRange, hasLength(2));
    expect(bucket.count, inRange.length);
  });

  test('los assets sin fecha forman un grupo al final', () async {
    await repository.upsertAll([
      _local('dated', 2026, 9, 23),
      buildAsset(
        'u1',
        captureDate: DateTime.utc(1970),
        source: CaptureDateSource.unknown,
      ),
      buildAsset(
        'u2',
        captureDate: DateTime.utc(1970),
        source: CaptureDateSource.unknown,
      ),
    ]);

    final buckets = await repository.watchMonthBuckets().first;

    expect(buckets, const [
      MonthBucket(MonthKey(2026, 9), 1),
      MonthBucket(MonthKey.undated(), 2),
    ]);
    const undated = MonthKey.undated();
    final inRange = await repository.inRange(
      fromInclusive: undated.startUtc,
      toExclusive: undated.endUtc,
    );
    expect(inRange, hasLength(2));
  });

  test('emite de nuevo cuando llegan assets', () async {
    final emissions = <List<MonthBucket>>[];
    final subscription = repository.watchMonthBuckets().listen(emissions.add);
    addTearDown(subscription.cancel);

    await repository.upsertAll([_local('a', 2026, 9, 1)]);
    await pumpEventQueue();
    await repository.upsertAll([_local('b', 2026, 9, 2)]);
    await pumpEventQueue();

    expect(emissions.last, const [MonthBucket(MonthKey(2026, 9), 2)]);
  });
}
