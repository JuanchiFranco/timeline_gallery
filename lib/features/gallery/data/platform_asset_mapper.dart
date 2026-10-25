import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

/// Convierte los campos crudos de un asset de plataforma en un [MediaAsset].
///
/// Es una función pura, sin dependencia de `photo_manager`, para poder
/// probar todos los casos borde (fechas ausentes, ubicación vacía, rotación
/// rara) sin plataforma.
///
/// Una fecha solo se acepta como fecha de captura si es plausible: entre 1990
/// y mañana. Los relojes sin configurar (1970, 1980) y los relojes
/// adelantados producen fechas que, aceptadas, dejarían una foto "de 2099" al
/// tope del timeline y estirarían el calendario cientos de meses. [now] se
/// inyecta para poder probarlo.
MediaAsset mapPlatformAsset({
  required String id,
  required bool isVideo,
  required int? createSeconds,
  required int? modifiedSeconds,
  required int width,
  required int height,
  int orientation = 0,
  int durationSeconds = 0,
  double? latitude,
  double? longitude,
  String? mimeType,
  DateTime? now,
}) {
  final latest =
      (now ?? DateTime.now())
          .toUtc()
          .add(_futureTolerance)
          .millisecondsSinceEpoch ~/
      1000;
  bool plausible(int? seconds) =>
      seconds != null &&
      seconds >= _earliestPlausibleSeconds &&
      seconds <= latest;

  final created = plausible(createSeconds) ? createSeconds : null;
  final modified = plausible(modifiedSeconds) ? modifiedSeconds : null;

  final DateTime captureDate;
  final CaptureDateSource source;
  if (created != null) {
    captureDate = _fromSeconds(created);
    source = CaptureDateSource.captured;
  } else if (modified != null) {
    captureDate = _fromSeconds(modified);
    source = CaptureDateSource.modified;
  } else {
    captureDate = _fromSeconds(0);
    source = CaptureDateSource.unknown;
  }

  // La plataforma devuelve 0/0 cuando no hay ubicación; no es una coordenada.
  final hasLocation =
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  return MediaAsset(
    platformAssetId: id,
    type: isVideo ? MediaType.video : MediaType.image,
    captureDate: captureDate,
    captureDateSource: source,
    // Es solo una marca de cambio para la sincronización, no una fecha para
    // mostrar: se conserva tal cual aunque no sea plausible.
    modifiedDate: (modifiedSeconds ?? 0) > 0
        ? _fromSeconds(modifiedSeconds!)
        : captureDate,
    width: width,
    height: height,
    orientation: normalizeOrientation(orientation),
    durationMs: isVideo ? durationSeconds * 1000 : null,
    mimeType: mimeType ?? (isVideo ? 'video/*' : 'image/*'),
    latitude: hasLocation ? latitude : null,
    longitude: hasLocation ? longitude : null,
  );
}

/// Lleva cualquier ángulo al múltiplo de 90 más cercano en `[0, 360)`.
int normalizeOrientation(int degrees) {
  final wrapped = ((degrees % 360) + 360) % 360;
  return ((wrapped + 45) ~/ 90 % 4) * 90;
}

/// 1990-01-01 UTC. Antes de eso no existen cámaras digitales de consumo: son
/// relojes sin configurar.
final _earliestPlausibleSeconds =
    DateTime.utc(1990).millisecondsSinceEpoch ~/ 1000;

/// Margen para husos horarios y pequeños desajustes de reloj.
const _futureTolerance = Duration(days: 1);

DateTime _fromSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
