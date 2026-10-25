import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_media_index_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

import '../../../support/fixtures.dart';

/// Capturado en la hora local indicada (los tests no dependen de la zona
/// horaria de la máquina).
MediaAsset _local(
  String id,
  int year,
  int month,
  int day, [
  int hour = 12,
  int minute = 0,
]) => buildAsset(
  id,
  captureDate: DateTime(year, month, day, hour, minute).toUtc(),
);

void main() {
  late AppDatabase db;
  late DriftMediaIndexRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftMediaIndexRepository(db, AppLogger(enabled: false));
  });

  tearDown(() => db.close());

  Future<List<DayBucket>> days() => repository.watchDayBuckets().first;

  test('sin assets no hay días', () async {
    expect(await days(), isEmpty);
  });

  test('un resumen por día local, del más reciente al más antiguo', () async {
    await repository.upsertAll([
      _local('a', 2025, 12, 31),
      _local('b', 2026, 9, 1),
      _local('c', 2026, 9, 23, 8),
      _local('d', 2026, 9, 23, 9),
      _local('e', 2026, 10, 2),
    ]);

    final result = await days();

    expect(result.map((d) => d.date), [
      DateTime(2026, 10, 2),
      DateTime(2026, 9, 23),
      DateTime(2026, 9, 1),
      DateTime(2025, 12, 31),
    ]);
    expect(result.map((d) => d.count), [1, 2, 1, 1]);
  });

  test('la portada es el asset más reciente del día', () async {
    await repository.upsertAll([
      _local('manana', 2026, 9, 23, 8),
      _local('noche', 2026, 9, 23, 22),
      _local('tarde', 2026, 9, 23, 15),
    ]);

    final day = (await days()).single;

    expect(day.coverAssetId, 'noche');
    expect(day.count, 3);
  });

  test('el día se decide en hora local, no en UTC', () async {
    // 23:59 local cuenta para ese día aunque en UTC ya pueda ser el siguiente.
    await repository.upsertAll([
      _local('tarde', 2026, 9, 23, 23, 59),
      _local('inicio', 2026, 9, 24, 0, 0),
    ]);

    final result = await days();

    expect(result.map((d) => d.date), [
      DateTime(2026, 9, 24),
      DateTime(2026, 9, 23),
    ]);
  });

  test(
    'el rango de MonthKey coincide con lo que cuentan los días del mes',
    () async {
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
      final month = monthBucketsFrom(
        await days(),
      ).firstWhere((m) => m.key == key);

      expect(inRange, hasLength(2));
      expect(month.count, inRange.length);
    },
  );

  test('el rango de un día coincide con su resumen', () async {
    await repository.upsertAll([
      _local('a', 2026, 9, 23, 0, 0),
      _local('b', 2026, 9, 23, 23, 59),
      _local('c', 2026, 9, 22, 23, 59),
      _local('d', 2026, 9, 24, 0, 0),
    ]);
    final day = DateTime(2026, 9, 23);

    final inRange = await repository.inRange(
      fromInclusive: day.toUtc(),
      toExclusive: DateTime(2026, 9, 24).toUtc(),
    );
    final summary = (await days()).firstWhere((d) => d.date == day);

    expect(summary.count, 2);
    expect(inRange, hasLength(summary.count));
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

    final result = await days();

    expect(result, hasLength(2));
    expect(result.last.isUndated, isTrue);
    expect(result.last.count, 2);
    expect(result.first.isUndated, isFalse);
    // Y su rango es el que usa el visor para el grupo sin fecha.
    const undated = MonthKey.undated();
    final inRange = await repository.inRange(
      fromInclusive: undated.startUtc,
      toExclusive: undated.endUtc,
    );
    expect(inRange, hasLength(2));
  });

  test('emite de nuevo cuando llegan assets', () async {
    final emissions = <List<DayBucket>>[];
    final subscription = repository.watchDayBuckets().listen(emissions.add);
    addTearDown(subscription.cancel);

    await repository.upsertAll([_local('a', 2026, 9, 1)]);
    await pumpEventQueue();
    await repository.upsertAll([_local('b', 2026, 9, 1, 13)]);
    await pumpEventQueue();

    expect(emissions.last.single.count, 2);
  });

  group('modifiedDatesOf', () {
    test('devuelve solo los pedidos que están indexados', () async {
      await repository.upsertAll([
        buildAsset('a', modifiedDate: DateTime.utc(2026, 1, 1)),
        buildAsset('b', modifiedDate: DateTime.utc(2026, 2, 2)),
        buildAsset('c'),
      ]);

      final result = await repository.modifiedDatesOf(['a', 'b', 'nuevo']);

      expect(result, {
        'a': DateTime.utc(2026, 1, 1),
        'b': DateTime.utc(2026, 2, 2),
      });
    });

    test('sin ids no toca la base', () async {
      expect(await repository.modifiedDatesOf(const []), isEmpty);
    });

    test(
      'más ids que el límite de variables de SQLite se parten en lotes',
      () async {
        final assets = [for (var i = 0; i < 1500; i++) buildAsset('id-$i')];
        await repository.upsertAll(assets);

        final result = await repository.modifiedDatesOf(
          assets.map((a) => a.platformAssetId),
        );

        expect(result, hasLength(1500));
      },
    );
  });
}
