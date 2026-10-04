import 'package:galeria_eventos/features/calendar/domain/calendar.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

/// Valor del parámetro de fecha para los assets sin fecha confiable.
const undatedViewerParam = 'sin-fecha';

/// Ubicación del visor de [asset]. El visor navega entre los assets de su mismo
/// día (o del grupo sin fecha), por eso la ruta lleva el día y el asset.
///
/// El id se codifica: los `localIdentifier` de iOS contienen `/`.
String viewerLocation(MediaAsset asset) {
  final day = asset.captureDateSource == CaptureDateSource.unknown
      ? undatedViewerParam
      : dayRouteParam(asset.captureDate.toLocal());
  return '/viewer/$day/${Uri.encodeComponent(asset.platformAssetId)}';
}

/// Interpreta el parámetro de fecha de la ruta: `null` es el grupo sin fecha,
/// [InvalidViewerDate] si no es ni eso ni un día válido.
sealed class ViewerDay {
  const ViewerDay();

  static ViewerDay parse(String param) {
    if (param == undatedViewerParam) return const UndatedViewerDay();
    final date = parseDayParam(param);
    return date == null ? const InvalidViewerDay() : DatedViewerDay(date);
  }
}

final class DatedViewerDay extends ViewerDay {
  const DatedViewerDay(this.date);

  /// Medianoche local del día.
  final DateTime date;
}

final class UndatedViewerDay extends ViewerDay {
  const UndatedViewerDay();
}

final class InvalidViewerDay extends ViewerDay {
  const InvalidViewerDay();
}
