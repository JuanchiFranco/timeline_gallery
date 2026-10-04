import 'package:flutter/foundation.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';

/// Celdas de la grilla de un mes, con la semana empezando en lunes: `null`
/// para los huecos antes del día 1 y después del último día, de modo que la
/// cantidad siempre sea múltiplo de 7.
List<DateTime?> monthGridCells(int year, int month) {
  final first = DateTime(year, month);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final leading = first.weekday - DateTime.monday;
  final trailing = (7 - (leading + daysInMonth) % 7) % 7;
  return [
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= daysInMonth; day++) DateTime(year, month, day),
    for (var i = 0; i < trailing; i++) null,
  ];
}

/// Lo que el calendario muestra de un día: cuántos assets tiene y cuál usar
/// como portada (el más reciente).
@immutable
class DaySummary {
  const DaySummary({required this.count, required this.cover});

  final int count;
  final MediaAsset cover;
}

/// Resumen por día del mes (clave: día del mes, 1 a 31) a partir de los días
/// ya agrupados. Ignora el grupo sin fecha.
Map<int, DaySummary> summarizeDays(List<TimelineDay> days) {
  return {
    for (final day in days)
      if (day.date != null && day.moments.isNotEmpty)
        day.date!.day: DaySummary(
          count: day.count,
          cover: day.moments.first.assets.first,
        ),
  };
}

/// Meses consecutivos que cubre el calendario: desde el más antiguo hasta el
/// más reciente con assets, sin huecos. Vacío si no hay assets con fecha.
///
/// [buckets] viene ordenado del más reciente al más antiguo.
List<MonthKey> calendarMonths(List<MonthBucket> buckets) {
  final dated = buckets.where((b) => !b.key.isUndated).toList();
  if (dated.isEmpty) return const [];
  final newest = dated.first.key;
  final oldest = dated.last.key;
  final total =
      (newest.year - oldest.year) * 12 + newest.month - oldest.month + 1;
  return [
    for (var i = 0; i < total; i++)
      MonthKey(
        oldest.year + (oldest.month - 1 + i) ~/ 12,
        (oldest.month - 1 + i) % 12 + 1,
      ),
  ];
}

/// `2026-09-23`, el formato del día en la ruta.
String dayRouteParam(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Inverso de [dayRouteParam]; `null` si no es una fecha válida (por ejemplo
/// `2026-02-31`, que `DateTime` desbordaría al 3 de marzo).
DateTime? parseDayParam(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  final valid = date.year == year && date.month == month && date.day == day;
  return valid ? date : null;
}

/// Ubicación de la pantalla de un día dentro de la pestaña Calendario.
String dayLocation(DateTime date) => '/calendar/day/${dayRouteParam(date)}';
