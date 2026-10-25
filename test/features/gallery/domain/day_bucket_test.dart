import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

void main() {
  final day = DateTime(2026, 9, 23);

  test('igualdad por valor y hashCode coherente', () {
    final a = DayBucket(date: day, count: 3, coverAssetId: 'x');
    final b = DayBucket(date: day, count: 3, coverAssetId: 'x');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({a, b}, hasLength(1));
  });

  test('cualquier campo distinto rompe la igualdad', () {
    final base = DayBucket(date: day, count: 3, coverAssetId: 'x');

    expect(
      base,
      isNot(
        DayBucket(date: DateTime(2026, 9, 24), count: 3, coverAssetId: 'x'),
      ),
    );
    expect(base, isNot(DayBucket(date: day, count: 4, coverAssetId: 'x')));
    expect(base, isNot(DayBucket(date: day, count: 3, coverAssetId: 'y')));
    expect(
      base,
      isNot(const DayBucket(date: null, count: 3, coverAssetId: 'x')),
    );
  });

  test('month y isUndated', () {
    final dated = DayBucket(date: day, count: 1, coverAssetId: 'x');
    const undated = DayBucket(date: null, count: 1, coverAssetId: 'x');

    expect(dated.isUndated, isFalse);
    expect(dated.month, const MonthKey(2026, 9));
    expect(undated.isUndated, isTrue);
    expect(undated.month, const MonthKey.undated());
  });

  test('toString no incluye el id del asset (privacidad en logs)', () {
    final text = DayBucket(
      date: day,
      count: 2,
      coverAssetId: 'secreto',
    ).toString();

    expect(text, contains('2'));
    expect(text, isNot(contains('secreto')));
  });
}
