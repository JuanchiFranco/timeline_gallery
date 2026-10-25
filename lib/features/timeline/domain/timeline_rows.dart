import 'package:flutter/foundation.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

/// Una fila de la lista del timeline. La lista es plana (año, mes, día, día…)
/// para poder construirse de forma perezosa fila a fila: solo los días que
/// están en pantalla piden sus assets.
@immutable
sealed class TimelineRow {
  const TimelineRow();

  /// Identificador estable, para conservar el estado de cada fila cuando la
  /// lista cambia (por ejemplo, mientras se sincroniza).
  String get id;
}

final class YearRow extends TimelineRow {
  const YearRow(this.year);

  final int year;

  @override
  String get id => 'y$year';
}

final class MonthRow extends TimelineRow {
  const MonthRow(this.key, this.count);

  final MonthKey key;

  /// Assets del mes completo.
  final int count;

  @override
  String get id => key.isUndated ? 'mu' : 'm${key.year}-${key.month}';
}

final class DayRow extends TimelineRow {
  const DayRow(this.date, this.count);

  /// Medianoche local.
  final DateTime date;
  final int count;

  @override
  String get id => 'd${date.year}-${date.month}-${date.day}';
}

/// Los assets sin fecha confiable: una sola fila.
final class UndatedRow extends TimelineRow {
  const UndatedRow(this.count);

  final int count;

  @override
  String get id => 'u';
}

/// Convierte los resúmenes por día (del más reciente al más antiguo) en las
/// filas del timeline: encabezado de año cuando cambia el año, de mes cuando
/// cambia el mes, y una fila por día. El grupo sin fecha va al final.
List<TimelineRow> buildTimelineRows(List<DayBucket> days) {
  final rows = <TimelineRow>[];
  final monthTotals = <MonthKey, int>{
    for (final month in monthBucketsFrom(days)) month.key: month.count,
  };

  int? lastYear;
  MonthKey? lastMonth;
  var undatedCount = 0;

  for (final day in days) {
    final date = day.date;
    if (date == null) {
      undatedCount += day.count;
      continue;
    }
    if (date.year != lastYear) {
      rows.add(YearRow(date.year));
      lastYear = date.year;
      lastMonth = null;
    }
    final month = day.month;
    if (month != lastMonth) {
      rows.add(MonthRow(month, monthTotals[month]!));
      lastMonth = month;
    }
    rows.add(DayRow(date, day.count));
  }

  if (undatedCount > 0) {
    rows
      ..add(MonthRow(const MonthKey.undated(), undatedCount))
      ..add(UndatedRow(undatedCount));
  }
  return rows;
}
