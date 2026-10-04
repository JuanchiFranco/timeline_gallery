import 'package:flutter/foundation.dart';

enum MediaType { image, video }

/// De dónde salió [MediaAsset.captureDate]. Permite marcar visualmente las
/// fechas inciertas (fotos importadas sin metadata de captura).
enum CaptureDateSource {
  /// Fecha real de captura (EXIF / `DATE_TAKEN` / `creationDate`).
  captured,

  /// No había fecha de captura: se usó la de modificación.
  modified,

  /// No había ninguna fecha confiable.
  unknown,
}

/// Referencia a un asset de la galería del dispositivo más sus metadatos.
///
/// Nunca contiene los bytes del archivo: [platformAssetId] es el identificador
/// que entrega la plataforma (`_ID` de MediaStore o `localIdentifier` de
/// PhotoKit) y con él se resuelve el archivo o la miniatura bajo demanda.
@immutable
class MediaAsset {
  const MediaAsset({
    required this.platformAssetId,
    required this.type,
    required this.captureDate,
    required this.captureDateSource,
    required this.modifiedDate,
    required this.width,
    required this.height,
    required this.mimeType,
    this.orientation = 0,
    this.durationMs,
    this.latitude,
    this.longitude,
    this.isFavorite = false,
  });

  final String platformAssetId;
  final MediaType type;

  /// Instante de captura en UTC. Se convierte a hora local solo al presentar.
  final DateTime captureDate;
  final CaptureDateSource captureDateSource;
  final DateTime modifiedDate;

  final int width;
  final int height;

  /// Rotación en grados (0, 90, 180, 270) a aplicar al mostrar el original.
  final int orientation;

  /// Solo para videos.
  final int? durationMs;
  final String mimeType;

  /// Solo si el sistema operativo entregó la ubicación (permiso del usuario).
  final double? latitude;
  final double? longitude;

  /// Estado local de la app; no se sincroniza con Google/Apple Photos.
  final bool isFavorite;

  bool get isVideo => type == MediaType.video;

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  MediaAsset copyWith({bool? isFavorite}) => MediaAsset(
    platformAssetId: platformAssetId,
    type: type,
    captureDate: captureDate,
    captureDateSource: captureDateSource,
    modifiedDate: modifiedDate,
    width: width,
    height: height,
    mimeType: mimeType,
    orientation: orientation,
    durationMs: durationMs,
    latitude: latitude,
    longitude: longitude,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAsset &&
          platformAssetId == other.platformAssetId &&
          type == other.type &&
          captureDate == other.captureDate &&
          captureDateSource == other.captureDateSource &&
          modifiedDate == other.modifiedDate &&
          width == other.width &&
          height == other.height &&
          orientation == other.orientation &&
          durationMs == other.durationMs &&
          mimeType == other.mimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          isFavorite == other.isFavorite;

  @override
  int get hashCode => Object.hash(
    platformAssetId,
    type,
    captureDate,
    captureDateSource,
    modifiedDate,
    width,
    height,
    orientation,
    durationMs,
    mimeType,
    latitude,
    longitude,
    isFavorite,
  );
}
