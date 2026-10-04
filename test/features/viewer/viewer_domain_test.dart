import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/viewer/domain/viewer.dart';

import '../../support/fixtures.dart';

void main() {
  group('viewerLocation', () {
    test('usa el día local del asset y el id codificado', () {
      final asset = buildAsset(
        'ABC/L0/001',
        captureDate: DateTime(2026, 9, 23, 23, 50).toUtc(),
      );

      expect(viewerLocation(asset), '/viewer/2026-09-23/ABC%2FL0%2F001');
    });

    test('los assets sin fecha van al grupo sin fecha', () {
      final asset = buildAsset(
        'u1',
        captureDate: DateTime.utc(1970),
        source: CaptureDateSource.unknown,
      );

      expect(viewerLocation(asset), '/viewer/sin-fecha/u1');
    });

    test('el id codificado se recupera tal cual desde la ruta', () {
      final location = viewerLocation(buildAsset('ABC/L0/001'));

      final segment = Uri.parse(location).pathSegments.last;

      expect(segment, 'ABC/L0/001');
    });
  });

  group('ViewerDay.parse', () {
    test('reconoce un día válido', () {
      final day = ViewerDay.parse('2026-09-23');

      expect(day, isA<DatedViewerDay>());
      expect((day as DatedViewerDay).date, DateTime(2026, 9, 23));
    });

    test('reconoce el grupo sin fecha', () {
      expect(ViewerDay.parse('sin-fecha'), isA<UndatedViewerDay>());
    });

    test('rechaza todo lo demás', () {
      expect(ViewerDay.parse('2026-02-31'), isA<InvalidViewerDay>());
      expect(ViewerDay.parse('ayer'), isA<InvalidViewerDay>());
      expect(ViewerDay.parse(''), isA<InvalidViewerDay>());
    });
  });
}
