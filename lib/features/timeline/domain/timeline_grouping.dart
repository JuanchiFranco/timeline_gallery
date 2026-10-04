import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';

/// Separación máxima entre dos assets consecutivos para que sigan siendo el
/// mismo momento.
const defaultMomentGap = Duration(minutes: 90);

/// Agrupa [assets] (del más reciente al más antiguo) en días locales y, dentro
/// de cada día, en momentos.
///
/// El día se calcula en hora local aquí y no en la base de datos, así la zona
/// horaria y el horario de verano solo se resuelven al presentar.
/// Los assets sin fecha confiable van todos a un único día sin fecha y un
/// único momento: su orden temporal no significa nada.
List<TimelineDay> groupIntoDays(
  List<MediaAsset> assets, {
  Duration momentGap = defaultMomentGap,
}) {
  final days = <TimelineDay>[];
  final undated = <MediaAsset>[];

  DateTime? currentDay;
  var moments = <TimelineMoment>[];
  var moment = <MediaAsset>[];

  void closeMoment() {
    if (moment.isEmpty) return;
    moments.add(TimelineMoment(moment));
    moment = <MediaAsset>[];
  }

  void closeDay() {
    closeMoment();
    if (currentDay == null) return;
    days.add(TimelineDay(date: currentDay, moments: moments));
    moments = <TimelineMoment>[];
  }

  for (final asset in assets) {
    if (asset.captureDateSource == CaptureDateSource.unknown) {
      undated.add(asset);
      continue;
    }

    final local = asset.captureDate.toLocal();
    final day = DateTime(local.year, local.month, local.day);

    if (currentDay != day) {
      closeDay();
      currentDay = day;
    } else if (moment.isNotEmpty &&
        moment.last.captureDate.difference(asset.captureDate) > momentGap) {
      closeMoment();
    }
    moment.add(asset);
  }
  closeDay();

  if (undated.isNotEmpty) {
    days.add(TimelineDay(date: null, moments: [TimelineMoment(undated)]));
  }
  return days;
}
