import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/database/app_database.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/drift_sync_state_store.dart';
import 'package:galeria_eventos/features/gallery/domain/repositories/sync_state_store.dart';

void main() {
  late AppDatabase db;
  late DriftSyncStateStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSyncStateStore(db, AppLogger(enabled: false));
  });

  tearDown(() => db.close());

  test('devuelve null para una clave que nunca se escribió', () async {
    expect(await store.read(SyncStateKey.mediaStoreGeneration), isNull);
  });

  test('escribe y lee un valor', () async {
    await store.write(SyncStateKey.mediaStoreGeneration, '1042');

    expect(await store.read(SyncStateKey.mediaStoreGeneration), '1042');
  });

  test('sobrescribe el valor anterior de la misma clave', () async {
    await store.write(SyncStateKey.checkpoint, '500');
    await store.write(SyncStateKey.checkpoint, '1000');

    expect(await store.read(SyncStateKey.checkpoint), '1000');
  });

  test('las claves son independientes entre sí', () async {
    await store.write(SyncStateKey.mediaStoreVersion, 'v1');
    await store.write(SyncStateKey.mediaStoreGeneration, '7');

    expect(await store.read(SyncStateKey.mediaStoreVersion), 'v1');
    expect(await store.read(SyncStateKey.mediaStoreGeneration), '7');
  });

  test('clear olvida todo el estado', () async {
    await store.write(SyncStateKey.mediaStoreVersion, 'v1');
    await store.write(SyncStateKey.checkpoint, '500');

    await store.clear();

    expect(await store.read(SyncStateKey.mediaStoreVersion), isNull);
    expect(await store.read(SyncStateKey.checkpoint), isNull);
  });
}
