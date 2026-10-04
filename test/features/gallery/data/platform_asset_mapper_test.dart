import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/data/platform_asset_mapper.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

MediaAsset _map({
  int? created = 1790000000,
  int? modified = 1790000500,
  bool isVideo = false,
  int orientation = 0,
  int durationSeconds = 0,
  double? latitude,
  double? longitude,
  String? mimeType,
}) {
  return mapPlatformAsset(
    id: 'a1',
    isVideo: isVideo,
    createSeconds: created,
    modifiedSeconds: modified,
    width: 4000,
    height: 3000,
    orientation: orientation,
    durationSeconds: durationSeconds,
    latitude: latitude,
    longitude: longitude,
    mimeType: mimeType,
  );
}

void main() {
  group('fechas', () {
    test('con fecha de creación usa esa y la marca como capturada', () {
      final asset = _map();

      expect(asset.captureDate, DateTime.utc(2026, 9, 21, 14, 13, 20));
      expect(asset.captureDateSource, CaptureDateSource.captured);
      expect(asset.captureDate.isUtc, isTrue);
      expect(
        asset.modifiedDate,
        asset.captureDate.add(const Duration(seconds: 500)),
      );
    });

    test('sin creación (null o 0) cae a la de modificación', () {
      for (final created in <int?>[null, 0]) {
        final asset = _map(created: created);

        expect(asset.captureDateSource, CaptureDateSource.modified);
        expect(asset.captureDate, asset.modifiedDate);
      }
    });

    test('sin ninguna fecha queda como desconocida en la época', () {
      final asset = _map(created: null, modified: 0);

      expect(asset.captureDateSource, CaptureDateSource.unknown);
      expect(asset.captureDate, DateTime.utc(1970));
      expect(asset.modifiedDate, asset.captureDate);
    });
  });

  group('tipo y duración', () {
    test('imagen no tiene duración', () {
      final asset = _map(durationSeconds: 5);

      expect(asset.type, MediaType.image);
      expect(asset.durationMs, isNull);
      expect(asset.mimeType, 'image/*');
    });

    test('video convierte segundos a milisegundos', () {
      final asset = _map(isVideo: true, durationSeconds: 12);

      expect(asset.type, MediaType.video);
      expect(asset.durationMs, 12000);
      expect(asset.mimeType, 'video/*');
    });

    test('respeta el mimeType que entrega la plataforma', () {
      expect(_map(mimeType: 'image/heic').mimeType, 'image/heic');
    });
  });

  group('ubicación', () {
    test('0/0 se trata como ausente', () {
      final asset = _map(latitude: 0, longitude: 0);

      expect(asset.latitude, isNull);
      expect(asset.longitude, isNull);
    });

    test('una coordenada real se conserva', () {
      final asset = _map(latitude: -34.6, longitude: -58.4);

      expect(asset.latitude, -34.6);
      expect(asset.longitude, -58.4);
    });

    test('una coordenada incompleta se descarta', () {
      final asset = _map(latitude: -34.6);

      expect(asset.latitude, isNull);
      expect(asset.longitude, isNull);
    });
  });

  group('normalizeOrientation', () {
    test('deja intactos los múltiplos de 90', () {
      for (final degrees in [0, 90, 180, 270]) {
        expect(normalizeOrientation(degrees), degrees);
      }
    });

    test('envuelve negativos y ángulos mayores a una vuelta', () {
      expect(normalizeOrientation(-90), 270);
      expect(normalizeOrientation(360), 0);
      expect(normalizeOrientation(450), 90);
    });

    test('redondea al múltiplo de 90 más cercano', () {
      expect(normalizeOrientation(44), 0);
      expect(normalizeOrientation(46), 90);
      expect(normalizeOrientation(350), 0);
    });
  });
}
