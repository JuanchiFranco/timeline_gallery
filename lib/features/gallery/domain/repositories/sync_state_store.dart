/// Claves del estado de sincronización persistido.
enum SyncStateKey {
  /// `MediaStore.getVersion()`: si cambia, hay que re-escanear todo (Android).
  mediaStoreVersion,

  /// `MediaStore.getGeneration()` visto en la última sincronización (Android).
  mediaStoreGeneration,

  /// Versión de las reglas con que se interpretan los assets de la plataforma
  /// (fechas, ubicación, rotación). Si cambia, lo ya indexado quedó con las
  /// reglas viejas y hay que re-escanear todo.
  mappingVersion,

  lastFullSyncAt,
  lastIncrementalSyncAt,

  /// Marca de reanudación del primer escaneo, para retomar tras una
  /// interrupción sin empezar de cero.
  checkpoint,
}

/// Almacén clave-valor del progreso de sincronización. Sobrevive a cierres y
/// reinicios de la app.
abstract interface class SyncStateStore {
  Future<String?> read(SyncStateKey key);
  Future<void> write(SyncStateKey key, String value);

  /// Olvida todo el estado (fuerza un re-escaneo completo).
  Future<void> clear();
}
