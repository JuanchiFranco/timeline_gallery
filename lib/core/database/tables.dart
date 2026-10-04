import 'package:drift/drift.dart';

/// Índice de metadatos de la galería. No contiene archivos ni miniaturas.
///
/// Las fechas se guardan como instantes (UTC); la conversión a día/hora local
/// ocurre solo en la capa de presentación para no depender de la zona horaria
/// ni del horario de verano al ordenar y consultar.
///
/// `type` y `captureDateSource` se guardan como códigos enteros estables
/// (mapeados en la capa de datos), para que el esquema no dependa del orden
/// de los enums del dominio.
@DataClassName('MediaAssetRow')
@TableIndex(name: 'idx_media_assets_capture_date', columns: {#captureDate})
@TableIndex(
  name: 'idx_media_assets_type_capture_date',
  columns: {#type, #captureDate},
)
@TableIndex(
  name: 'idx_media_assets_favorite_capture_date',
  columns: {#isFavorite, #captureDate},
)
class MediaAssets extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `_ID` de MediaStore o `localIdentifier` de PhotoKit.
  TextColumn get platformAssetId => text().unique()();

  /// 0 = imagen, 1 = video.
  IntColumn get type => integer()();

  DateTimeColumn get captureDate => dateTime()();

  /// 0 = capturada, 1 = modificación (fallback), 2 = desconocida.
  IntColumn get captureDateSource => integer()();

  DateTimeColumn get modifiedDate => dateTime()();

  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get orientation => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get mimeType => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Estado de sincronización (clave-valor).
@DataClassName('SyncStateRow')
class SyncStateEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
