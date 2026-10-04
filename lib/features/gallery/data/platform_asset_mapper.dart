import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

/// Convierte los campos crudos de un asset de plataforma en un [MediaAsset].
///
/// Es una función pura, sin dependencia de `photo_manager`, para poder
/// probar todos los casos borde (fechas ausentes, ubicación vacía, rotación
/// rara) sin plataforma.
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
}) {
  // 0 o ausente significa "sin dato" en ambas plataformas.
  final created = (createSeconds ?? 0) > 0 ? createSeconds! : null;
  final modified = (modifiedSeconds ?? 0) > 0 ? modifiedSeconds! : null;

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
    modifiedDate: modified != null ? _fromSeconds(modified) : captureDate,
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

DateTime _fromSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
