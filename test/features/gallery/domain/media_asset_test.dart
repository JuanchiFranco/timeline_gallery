import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

import '../../../support/fixtures.dart';

void main() {
  group('MediaAsset', () {
    test('la igualdad es por valor y hashCode es coherente', () {
      final a = buildAsset('x', width: 100);
      final b = buildAsset('x', width: 100);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('cualquier campo distinto rompe la igualdad', () {
      final base = buildAsset('x');

      expect(base, isNot(buildAsset('y')));
      expect(base, isNot(buildAsset('x', width: 1)));
      expect(base, isNot(buildAsset('x', height: 1)));
      expect(base, isNot(buildAsset('x', isFavorite: true)));
      expect(base, isNot(buildAsset('x', type: MediaType.video)));
      expect(base, isNot(buildAsset('x', source: CaptureDateSource.modified)));
      expect(
        base,
        isNot(
          buildAsset(
            'x',
            captureDate: DateTime.utc(2020),
            modifiedDate: DateTime.utc(2020),
          ),
        ),
      );
      expect(base, isNot(buildAsset('x', modifiedDate: DateTime.utc(2030))));
    });

    test('copyWith solo cambia isFavorite y conserva el resto', () {
      final original = buildAsset('x', type: MediaType.video);

      final favorite = original.copyWith(isFavorite: true);

      expect(favorite.isFavorite, isTrue);
      expect(favorite.platformAssetId, 'x');
      expect(favorite.type, MediaType.video);
      expect(favorite.durationMs, original.durationMs);
      expect(favorite.captureDate, original.captureDate);
      // Sin argumentos, queda igual.
      expect(original.copyWith(), original);
      // No muta el original.
      expect(original.isFavorite, isFalse);
    });

    test('isVideo y duration reflejan el tipo', () {
      final image = buildAsset('i');
      final video = buildAsset('v', type: MediaType.video);

      expect(image.isVideo, isFalse);
      expect(image.duration, isNull);
      expect(video.isVideo, isTrue);
      expect(video.duration, const Duration(seconds: 12));
    });
  });
}
