import 'package:flutter/foundation.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

/// Assets cercanos en el tiempo dentro de un mismo día (una salida, una
/// comida, una fiesta). Del más reciente al más antiguo.
@immutable
class TimelineMoment {
  const TimelineMoment(this.assets);

  final List<MediaAsset> assets;

  int get count => assets.length;

  /// Hora local del primer y del último asset del momento.
  DateTime get start => assets.last.captureDate.toLocal();
  DateTime get end => assets.first.captureDate.toLocal();
}

/// Un día local con sus momentos. [date] es `null` para el grupo sin fecha.
@immutable
class TimelineDay {
  const TimelineDay({required this.date, required this.moments});

  /// Medianoche local del día.
  final DateTime? date;
  final List<TimelineMoment> moments;

  int get count => moments.fold(0, (sum, moment) => sum + moment.count);
}
