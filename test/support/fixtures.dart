import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

/// Construye un asset de prueba. Las fechas usan segundos enteros porque el
/// índice guarda instantes con resolución de segundo.
MediaAsset buildAsset(
  String id, {
  DateTime? captureDate,
  DateTime? modifiedDate,
  MediaType type = MediaType.image,
  CaptureDateSource source = CaptureDateSource.captured,
  bool isFavorite = false,
  int width = 4000,
  int height = 3000,
}) {
  final captured = captureDate ?? DateTime.utc(2026, 9, 23, 8, 32);
  return MediaAsset(
    platformAssetId: id,
    type: type,
    captureDate: captured,
    captureDateSource: source,
    modifiedDate: modifiedDate ?? captured,
    width: width,
    height: height,
    mimeType: type == MediaType.video ? 'video/mp4' : 'image/jpeg',
    durationMs: type == MediaType.video ? 12000 : null,
    isFavorite: isFavorite,
  );
}
