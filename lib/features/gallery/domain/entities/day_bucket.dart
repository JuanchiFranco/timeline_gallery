import 'package:flutter/foundation.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

/// Resumen de un día del índice: cuántos assets tiene y cuál usar de portada.
///
/// Es lo único que necesitan la lista del timeline y el calendario para
/// decidir qué mostrar; los assets de cada día se piden solo cuando ese día
/// aparece en pantalla.
@immutable
class DayBucket {
  const DayBucket({
    required this.date,
    required this.count,
    required this.coverAssetId,
  });

  /// Medianoche **local** del día, o `null` para el grupo "sin fecha".
  final DateTime? date;
  final int count;

  /// `platformAssetId` del asset más reciente del día.
  final String coverAssetId;

  bool get isUndated => date == null;

  MonthKey get month {
    final day = date;
    return day == null
        ? const MonthKey.undated()
        : MonthKey(day.year, day.month);
  }

  @override
  bool operator ==(Object other) =>
      other is DayBucket &&
      date == other.date &&
      count == other.count &&
      coverAssetId == other.coverAssetId;

  @override
  int get hashCode => Object.hash(date, count, coverAssetId);

  @override
  String toString() => 'DayBucket($date, $count)';
}

/// Suma los días de cada mes. [days] viene del más reciente al más antiguo; el
/// resultado conserva ese orden y deja el grupo sin fecha, si existe, al final.
List<MonthBucket> monthBucketsFrom(List<DayBucket> days) {
  final counts = <MonthKey, int>{};
  for (final day in days) {
    if (day.isUndated) continue;
    counts.update(day.month, (n) => n + day.count, ifAbsent: () => day.count);
  }
  final undated = days
      .where((d) => d.isUndated)
      .fold<int>(0, (sum, d) => sum + d.count);
  return [
    for (final entry in counts.entries) MonthBucket(entry.key, entry.value),
    if (undated > 0) MonthBucket(const MonthKey.undated(), undated),
  ];
}
