import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/calendar/domain/calendar.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

void main() {
  group('monthGridCells', () {
    test('septiembre 2026 empieza en martes: 1 hueco antes y 4 después', () {
      final cells = monthGridCells(2026, 9);

      expect(cells, hasLength(35));
      expect(cells.take(2), [null, DateTime(2026, 9, 1)]);
      expect(cells.sublist(31), everyElement(isNull));
      expect(cells[30], DateTime(2026, 9, 30));
    });

    test('un mes que empieza en lunes no tiene huecos iniciales', () {
      final cells = monthGridCells(2027, 2);

      expect(cells.first, DateTime(2027, 2, 1));
      expect(cells, hasLength(28));
    });

    test('un mes que empieza en domingo tiene 6 huecos y 6 semanas', () {
      final cells = monthGridCells(2026, 3);

      expect(cells.take(6), everyElement(isNull));
      expect(cells[6], DateTime(2026, 3, 1));
      expect(cells, hasLength(42));
    });

    test('febrero bisiesto tiene 29 días', () {
      final days = monthGridCells(2028, 2).whereType<DateTime>();

      expect(days, hasLength(29));
    });

    test('siempre devuelve semanas completas', () {
      for (var month = 1; month <= 12; month++) {
        expect(monthGridCells(2026, month).length % 7, 0);
      }
    });
  });

  group('summarizeMonth', () {
    DayBucket day(int month, int d, int count, String cover) => DayBucket(
      date: DateTime(2026, month, d),
      count: count,
      coverAssetId: cover,
    );

    test('toma solo los días del mes pedido', () {
      final summary = summarizeMonth([
        day(10, 2, 1, 'oct'),
        day(9, 23, 3, 'late'),
        day(9, 5, 1, 'other'),
        day(8, 5, 9, 'ago'),
      ], const MonthKey(2026, 9));

      expect(summary.keys, unorderedEquals([23, 5]));
      expect(summary[23]!.count, 3);
      expect(summary[23]!.coverAssetId, 'late');
      expect(summary[5]!.coverAssetId, 'other');
    });

    test('no mezcla el mismo mes de otro año', () {
      final summary = summarizeMonth([
        DayBucket(date: DateTime(2025, 9, 23), count: 7, coverAssetId: 'viejo'),
        day(9, 23, 1, 'nuevo'),
      ], const MonthKey(2026, 9));

      expect(summary[23]!.coverAssetId, 'nuevo');
    });

    test('ignora el grupo sin fecha', () {
      final summary = summarizeMonth(const [
        DayBucket(date: null, count: 5, coverAssetId: 'u'),
      ], const MonthKey(2026, 9));

      expect(summary, isEmpty);
    });
  });

  group('calendarMonths', () {
    test('sin meses con fecha no hay calendario', () {
      expect(calendarMonths(const []), isEmpty);
      expect(
        calendarMonths(const [MonthBucket(MonthKey.undated(), 4)]),
        isEmpty,
      );
    });

    test('cubre sin huecos del mes más antiguo al más reciente', () {
      final months = calendarMonths(const [
        MonthBucket(MonthKey(2026, 10), 1),
        MonthBucket(MonthKey(2026, 9), 2),
        MonthBucket(MonthKey(2025, 11), 5),
        MonthBucket(MonthKey.undated(), 3),
      ]);

      expect(months, hasLength(12));
      expect(months.first, const MonthKey(2025, 11));
      expect(months.last, const MonthKey(2026, 10));
      // Pasa por diciembre y enero sin saltarse ni repetir meses.
      expect(months[1], const MonthKey(2025, 12));
      expect(months[2], const MonthKey(2026, 1));
    });

    test('un solo mes', () {
      expect(calendarMonths(const [MonthBucket(MonthKey(2026, 9), 1)]), [
        const MonthKey(2026, 9),
      ]);
    });
  });

  group('parámetro de ruta del día', () {
    test('ida y vuelta', () {
      final date = DateTime(2026, 9, 3);

      expect(dayRouteParam(date), '2026-09-03');
      expect(parseDayParam('2026-09-03'), date);
      expect(dayLocation(date), '/calendar/day/2026-09-03');
    });

    test('rechaza formatos y fechas inexistentes', () {
      expect(parseDayParam('hoy'), isNull);
      expect(parseDayParam('2026-9-3'), isNull);
      expect(parseDayParam('2026-13-01'), isNull);
      // DateTime desbordaría esto al 3 de marzo.
      expect(parseDayParam('2026-02-31'), isNull);
      expect(parseDayParam('2026-09-23 '), isNull);
    });

    test('acepta el 29 de febrero solo en año bisiesto', () {
      expect(parseDayParam('2028-02-29'), DateTime(2028, 2, 29));
      expect(parseDayParam('2026-02-29'), isNull);
    });
  });
}
