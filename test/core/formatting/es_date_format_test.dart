import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/formatting/es_date_format.dart';

void main() {
  final today = DateTime(2026, 10, 3, 15);

  group('day', () {
    test('hoy y ayer', () {
      expect(EsDateFormat.day(DateTime(2026, 10, 3), today: today), 'Hoy');
      expect(EsDateFormat.day(DateTime(2026, 10, 2), today: today), 'Ayer');
    });

    test('mismo año omite el año', () {
      expect(
        EsDateFormat.day(DateTime(2026, 9, 23), today: today),
        'Miércoles 23 de septiembre',
      );
    });

    test('otro año lo incluye', () {
      expect(
        EsDateFormat.day(DateTime(2025, 12, 31), today: today),
        'Miércoles 31 de diciembre de 2025',
      );
    });

    test('ayer cruza el cambio de mes', () {
      expect(
        EsDateFormat.day(DateTime(2026, 9, 30), today: DateTime(2026, 10, 1)),
        'Ayer',
      );
    });

    test('la hora de "today" no afecta la comparación', () {
      expect(
        EsDateFormat.day(
          DateTime(2026, 10, 2, 23, 59),
          today: DateTime(2026, 10, 3, 0, 1),
        ),
        'Ayer',
      );
    });
  });

  group('timeRange', () {
    test('rellena con ceros', () {
      expect(
        EsDateFormat.timeRange(
          DateTime(2026, 9, 23, 8, 5),
          DateTime(2026, 9, 23, 10, 15),
        ),
        '08:05 – 10:15',
      );
    });

    test('colapsa cuando inicio y fin coinciden al minuto', () {
      expect(
        EsDateFormat.timeRange(
          DateTime(2026, 9, 23, 8, 5, 10),
          DateTime(2026, 9, 23, 8, 5, 50),
        ),
        '08:05',
      );
    });
  });

  test('month capitaliza el nombre', () {
    expect(EsDateFormat.month(1), 'Enero');
    expect(EsDateFormat.month(12), 'Diciembre');
  });
}
