import 'dart:math';

import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/device_gallery_repository.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';

/// Galería sintética con forma realista: años de fotos en ráfagas (momentos)
/// dentro de cada día, algunos videos, y un mes "pesado" (viaje, fiesta) con
/// muchísimas más fotos que el resto.
///
/// Determinista (semilla fija) para que dos corridas sean comparables.
class SyntheticGallery {
  SyntheticGallery({int years = 10, int heavyMonthAssets = 3000}) {
    final random = Random(42);
    final assets = <MediaAsset>[];
    var id = 0;

    void addMoment(DateTime start, int count) {
      for (var i = 0; i < count; i++) {
        assets.add(
          buildAsset(
            'asset-${id++}',
            // Dentro del momento, una foto cada pocos minutos.
            captureDate: start.add(Duration(minutes: i * 2)),
            type: random.nextInt(12) == 0 ? MediaType.video : MediaType.image,
          ),
        );
      }
    }

    final first = DateTime(DateTime.now().year - years, 1, 1);
    final days = DateTime.now().difference(first).inDays;
    for (var d = 0; d < days; d++) {
      final day = DateTime(first.year, first.month, first.day + d);
      // Promedio ~14 por día; muchos días sin fotos.
      if (random.nextInt(4) == 0) continue;
      final moments = 1 + random.nextInt(3);
      for (var m = 0; m < moments; m++) {
        final hour = 8 + m * 4 + random.nextInt(3);
        addMoment(
          DateTime(day.year, day.month, day.day, hour).toUtc(),
          3 + random.nextInt(12),
        );
      }
    }

    // El mes pesado: ~100 fotos por día, en 4 momentos de ~25.
    final heavy = DateTime(DateTime.now().year - 1, 7);
    final perDay = heavyMonthAssets ~/ 30;
    for (var d = 0; d < 30; d++) {
      for (var m = 0; m < 4; m++) {
        addMoment(
          DateTime(heavy.year, heavy.month, 1 + d, 8 + m * 3).toUtc(),
          perDay ~/ 4,
        );
      }
    }
    this.assets = assets;
    heavyMonth = heavy;
  }

  late final List<MediaAsset> assets;
  late final DateTime heavyMonth;
}

/// Galería del dispositivo con los assets ya ordenados una vez, para que el
/// benchmark mida la sincronización y no el ordenamiento del fake.
class PresortedDevice implements DeviceGalleryRepository {
  PresortedDevice(List<MediaAsset> assets)
    : _sorted = List.of(assets)
        ..sort((a, b) {
          final byDate = b.captureDate.compareTo(a.captureDate);
          return byDate != 0
              ? byDate
              : b.platformAssetId.compareTo(a.platformAssetId);
        });

  final List<MediaAsset> _sorted;

  @override
  Future<int> totalCount() async => _sorted.length;

  @override
  Future<List<MediaAsset>> readPage({
    required int page,
    required int pageSize,
  }) async {
    final start = page * pageSize;
    if (start >= _sorted.length) return const [];
    final end = min(start + pageSize, _sorted.length);
    return _sorted.sublist(start, end);
  }
}

/// Índice en memoria con los assets ordenados una sola vez, para que el
/// benchmark de la interfaz mida la interfaz y no el filtrado lineal del fake
/// por defecto (que recorre todos los assets en cada consulta).
class PresortedIndex extends FakeMediaIndexRepository {
  PresortedIndex(super.assets)
    : _sorted = (List.of(assets)
        ..sort((a, b) => b.captureDate.compareTo(a.captureDate)));

  /// Del más reciente al más antiguo.
  final List<MediaAsset> _sorted;

  @override
  Stream<List<MediaAsset>> watchRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    // Búsqueda binaria de los extremos: `_sorted` es descendente.
    int firstBefore(DateTime limit) {
      var low = 0;
      var high = _sorted.length;
      while (low < high) {
        final mid = (low + high) ~/ 2;
        if (_sorted[mid].captureDate.isBefore(limit)) {
          high = mid;
        } else {
          low = mid + 1;
        }
      }
      return low;
    }

    // Con la lista descendente, los que cumplen from <= fecha < to son los que
    // van desde el primero estrictamente anterior a `to` hasta el primero
    // estrictamente anterior a `from`.
    return Stream.value(
      _sorted.sublist(firstBefore(toExclusive), firstBefore(fromInclusive)),
    );
  }
}
