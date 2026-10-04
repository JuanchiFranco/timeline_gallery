import 'package:drift/drift.dart';
import 'package:galeria_eventos/core/database/tables.dart';

part 'app_database.g.dart';

/// Base de datos local del índice de la galería.
///
/// Recibe el [QueryExecutor] desde fuera: la app usa `driftDatabase(...)`
/// (isolate en segundo plano) y los tests usan `NativeDatabase.memory()`.
@DriftDatabase(tables: [MediaAssets, SyncStateEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    // Cuando cambie el esquema: agregar un paso por versión aquí y un test
    // de migración en test/core/database.
  );
}
