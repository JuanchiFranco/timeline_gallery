import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';

/// Índice local de la galería. Es la única fuente de datos que lee la UI:
/// la galería del dispositivo solo la consulta el servicio de sincronización.
///
/// Todos los métodos pueden lanzar `StorageFailure`.
abstract interface class MediaIndexRepository {
  /// Inserta o actualiza por `platformAssetId`, en una sola transacción.
  /// Al actualizar conserva el estado local (`isFavorite`, `createdAt`).
  Future<void> upsertAll(List<MediaAsset> assets);

  /// Elimina del índice (no del dispositivo). Devuelve cuántas filas borró.
  Future<int> deleteByPlatformIds(Iterable<String> platformAssetIds);

  /// Todos los ids indexados; base del diff de altas/bajas en Android.
  Future<Set<String>> knownPlatformIds();

  /// Fecha de modificación indexada de cada asset; permite al sync detectar
  /// altas y ediciones sin releer todo.
  Future<Map<String, DateTime>> modifiedDates();

  Future<int> count();
  Stream<int> watchCount();

  /// Assets con `fromInclusive <= captureDate < toExclusive`, del más
  /// reciente al más antiguo.
  Future<List<MediaAsset>> inRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  });

  Stream<List<MediaAsset>> watchRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  });

  /// Meses (en hora local) que tienen assets y cuántos, del más reciente al
  /// más antiguo; el grupo sin fecha, si existe, va al final.
  Stream<List<MonthBucket>> watchMonthBuckets();
}
