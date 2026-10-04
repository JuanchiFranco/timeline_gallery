import 'package:flutter/foundation.dart';

/// Mes calendario en **hora local** del dispositivo, o el grupo "sin fecha".
@immutable
class MonthKey {
  const MonthKey(this.year, this.month) : assert(month >= 1 && month <= 12);

  /// Assets sin fecha confiable (`CaptureDateSource.unknown`).
  const MonthKey.undated() : year = 0, month = 0;

  final int year;
  final int month;

  bool get isUndated => year == 0;

  /// Rango UTC `[startUtc, endUtc)` de los instantes que caen en este mes
  /// local; es lo que se consulta al índice.
  DateTime get startUtc =>
      isUndated ? DateTime.utc(1970) : DateTime(year, month).toUtc();

  DateTime get endUtc =>
      isUndated ? DateTime.utc(1970, 1, 2) : DateTime(year, month + 1).toUtc();

  @override
  bool operator ==(Object other) =>
      other is MonthKey && year == other.year && month == other.month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() =>
      isUndated ? 'MonthKey.undated' : 'MonthKey($year-$month)';
}

/// Un mes con la cantidad de assets que contiene.
@immutable
class MonthBucket {
  const MonthBucket(this.key, this.count);

  final MonthKey key;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is MonthBucket && key == other.key && count == other.count;

  @override
  int get hashCode => Object.hash(key, count);
}
