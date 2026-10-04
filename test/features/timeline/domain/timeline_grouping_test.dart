import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_grouping.dart';

import '../../../support/fixtures.dart';

/// Asset capturado en la hora **local** indicada. Se construye así para que los
/// tests no dependan de la zona horaria de la máquina.
MediaAsset _at(
  String id,
  int day,
  int hour,
  int minute, {
  int month = 9,
  CaptureDateSource source = CaptureDateSource.captured,
}) => buildAsset(
  id,
  captureDate: DateTime(2026, month, day, hour, minute).toUtc(),
  source: source,
);

void main() {
  group('groupIntoDays', () {
    test('sin assets no hay días', () {
      expect(groupIntoDays(const []), isEmpty);
    });

    test('agrupa por día local, del más reciente al más antiguo', () {
      final days = groupIntoDays([
        _at('c', 24, 9, 0),
        _at('b', 23, 20, 0),
        _at('a', 23, 8, 0),
      ]);

      expect(days.map((d) => d.date), [
        DateTime(2026, 9, 24),
        DateTime(2026, 9, 23),
      ]);
      expect(days.map((d) => d.count), [1, 2]);
    });

    test('el día se decide en hora local, no en UTC', () {
      // 23:50 local sigue siendo el día 23 aunque en UTC ya sea el 24.
      final days = groupIntoDays([_at('late', 23, 23, 50)]);

      expect(days.single.date, DateTime(2026, 9, 23));
    });

    test('separa momentos cuando el hueco supera el umbral', () {
      final days = groupIntoDays([
        _at('e', 23, 20, 0),
        _at('d', 23, 19, 30),
        _at('c', 23, 12, 0),
        _at('b', 23, 10, 45),
        _at('a', 23, 10, 0),
      ]);

      final moments = days.single.moments;
      expect(moments, hasLength(2));
      expect(moments[0].assets.map((a) => a.platformAssetId), ['e', 'd']);
      expect(moments[1].assets.map((a) => a.platformAssetId), ['c', 'b', 'a']);
    });

    test('un hueco exactamente igual al umbral no corta el momento', () {
      final days = groupIntoDays([_at('b', 23, 11, 30), _at('a', 23, 10, 0)]);

      expect(days.single.moments, hasLength(1));
    });

    test('un momento no cruza la medianoche', () {
      final days = groupIntoDays([_at('b', 24, 0, 10), _at('a', 23, 23, 50)]);

      expect(days, hasLength(2));
      expect(days.every((d) => d.moments.length == 1), isTrue);
    });

    test('start y end del momento son las horas locales extremas', () {
      final moment = groupIntoDays([
        _at('b', 23, 10, 45),
        _at('a', 23, 10, 0),
      ]).single.moments.single;

      expect(moment.start, DateTime(2026, 9, 23, 10, 0));
      expect(moment.end, DateTime(2026, 9, 23, 10, 45));
    });

    test('el umbral es configurable', () {
      final assets = [_at('b', 23, 10, 20), _at('a', 23, 10, 0)];

      final days = groupIntoDays(
        assets,
        momentGap: const Duration(minutes: 10),
      );

      expect(days.single.moments, hasLength(2));
    });

    test('los assets sin fecha van a un único grupo sin fecha, al final', () {
      final days = groupIntoDays([
        _at('dated', 23, 10, 0),
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

      expect(days, hasLength(2));
      expect(days.last.date, isNull);
      expect(days.last.moments, hasLength(1));
      expect(days.last.count, 2);
    });
  });

  group('MonthKey', () {
    test('el rango cubre exactamente el mes local', () {
      const key = MonthKey(2026, 9);

      expect(key.startUtc, DateTime(2026, 9).toUtc());
      expect(key.endUtc, DateTime(2026, 10).toUtc());
    });

    test('diciembre termina en enero del año siguiente', () {
      const key = MonthKey(2026, 12);

      expect(key.endUtc, DateTime(2027).toUtc());
    });

    test('el grupo sin fecha cubre el día de la época', () {
      const key = MonthKey.undated();

      expect(key.isUndated, isTrue);
      expect(key.startUtc, DateTime.utc(1970));
      expect(key.endUtc, DateTime.utc(1970, 1, 2));
    });

    test('tiene igualdad por valor', () {
      expect(const MonthKey(2026, 9), const MonthKey(2026, 9));
      expect(const MonthKey(2026, 9), isNot(const MonthKey(2026, 10)));
    });
  });
}
