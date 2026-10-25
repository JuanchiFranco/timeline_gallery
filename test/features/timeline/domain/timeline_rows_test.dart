import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_rows.dart';

DayBucket _day(int year, int month, int day, [int count = 1]) => DayBucket(
  date: DateTime(year, month, day),
  count: count,
  coverAssetId: 'c-$year-$month-$day',
);

const _undated = DayBucket(date: null, count: 4, coverAssetId: 'u');

String _describe(TimelineRow row) => switch (row) {
  YearRow() => 'Y${row.year}',
  MonthRow() =>
    'M${row.key.isUndated ? 'u' : '${row.key.year}-${row.key.month}'}'
        '(${row.count})',
  DayRow() => 'D${row.date.month}/${row.date.day}(${row.count})',
  UndatedRow() => 'U(${row.count})',
};

void main() {
  group('buildTimelineRows', () {
    test('sin días no hay filas', () {
      expect(buildTimelineRows(const []), isEmpty);
    });

    test('año, mes y día en orden, con un encabezado por cambio', () {
      final rows = buildTimelineRows([
        _day(2026, 10, 2),
        _day(2026, 9, 23, 3),
        _day(2026, 9, 5, 2),
        _day(2025, 12, 31),
      ]);

      expect(rows.map(_describe), [
        'Y2026',
        'M2026-10(1)',
        'D10/2(1)',
        'M2026-9(5)',
        'D9/23(3)',
        'D9/5(2)',
        'Y2025',
        'M2025-12(1)',
        'D12/31(1)',
      ]);
    });

    test('el conteo del mes suma todos sus días', () {
      final rows = buildTimelineRows([
        _day(2026, 9, 3, 10),
        _day(2026, 9, 2, 20),
        _day(2026, 9, 1, 30),
      ]);

      expect(rows.whereType<MonthRow>().single.count, 60);
    });

    test('el mismo mes de otro año no se mezcla', () {
      final rows = buildTimelineRows([_day(2026, 9, 1), _day(2025, 9, 1)]);

      expect(rows.whereType<MonthRow>(), hasLength(2));
      expect(rows.whereType<YearRow>(), hasLength(2));
    });

    test('los assets sin fecha van al final, en su propio grupo', () {
      final rows = buildTimelineRows([_day(2026, 9, 23), _undated]);

      expect(rows.map(_describe), [
        'Y2026',
        'M2026-9(1)',
        'D9/23(1)',
        'Mu(4)',
        'U(4)',
      ]);
    });

    test('solo sin fecha: no hay encabezado de año', () {
      final rows = buildTimelineRows(const [_undated]);

      expect(rows.map(_describe), ['Mu(4)', 'U(4)']);
    });

    test('los ids son únicos y estables', () {
      final days = [
        _day(2026, 10, 2),
        _day(2026, 9, 23),
        _day(2025, 12, 31),
        _undated,
      ];

      final first = buildTimelineRows(days).map((r) => r.id).toList();
      final second = buildTimelineRows(days).map((r) => r.id).toList();

      expect(first.toSet(), hasLength(first.length));
      expect(second, first);
    });

    test('un día nuevo arriba no cambia los ids de las demás filas', () {
      final before = buildTimelineRows([_day(2026, 9, 23), _day(2026, 9, 5)]);
      final after = buildTimelineRows([
        _day(2026, 9, 24),
        _day(2026, 9, 23),
        _day(2026, 9, 5),
      ]);

      expect(
        after.map((r) => r.id).toSet().containsAll(before.map((r) => r.id)),
        isTrue,
      );
    });
  });

  group('monthBucketsFrom', () {
    test('suma por mes conservando el orden y deja sin fecha al final', () {
      final months = monthBucketsFrom([
        _undated,
        _day(2026, 9, 23, 3),
        _day(2026, 9, 5, 2),
        _day(2025, 12, 31),
      ]);

      expect(months, const [
        MonthBucket(MonthKey(2026, 9), 5),
        MonthBucket(MonthKey(2025, 12), 1),
        MonthBucket(MonthKey.undated(), 4),
      ]);
    });

    test('sin días no hay meses', () {
      expect(monthBucketsFrom(const []), isEmpty);
    });
  });
}
