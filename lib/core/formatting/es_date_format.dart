/// Formato de fechas y horas en español, sin dependencias: la app solo está
/// disponible en este idioma por ahora. Si se agrega otro, reemplazar por
/// `intl` con las localizaciones de Flutter.
abstract final class EsDateFormat {
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  /// "Septiembre" (mes 1 a 12).
  static String month(int month) => _capitalize(_months[month - 1]);

  /// "Miércoles 23 de septiembre", con "Hoy" y "Ayer" para los días cercanos.
  /// [date] y [today] son fechas locales; se compara solo año/mes/día.
  static String day(DateTime date, {required DateTime today}) {
    final days = _dateOnly(today).difference(_dateOnly(date)).inDays;
    if (days == 0) return 'Hoy';
    if (days == 1) return 'Ayer';
    final weekday = _capitalize(_weekdays[date.weekday - 1]);
    final base = '$weekday ${date.day} de ${_months[date.month - 1]}';
    return date.year == today.year ? base : '$base de ${date.year}';
  }

  /// "08:32" o, si el rango abarca más de un minuto, "08:32 – 10:15".
  static String timeRange(DateTime start, DateTime end) {
    final from = _time(start);
    final to = _time(end);
    return from == to ? from : '$from – $to';
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _capitalize(String text) =>
      text[0].toUpperCase() + text.substring(1);
}
