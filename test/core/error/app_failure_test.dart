import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';

void main() {
  group('asAppFailure', () {
    test('devuelve la misma instancia si ya es un AppFailure', () {
      const original = StorageFailure('disk');

      expect(asAppFailure(original, StackTrace.empty), same(original));
    });

    test('envuelve errores desconocidos sin perder el original', () {
      final cause = StateError('boom');
      final stack = StackTrace.current;

      final failure = asAppFailure(cause, stack);

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.cause, same(cause));
      expect(failure.stackTrace, same(stack));
    });
  });

  group('AppFailure', () {
    test('toString no filtra el contenido del error original', () {
      final failure = StorageFailure(
        'upsertAll failed',
        cause: Exception('/storage/emulated/0/DCIM/private.jpg'),
      );

      expect(failure.toString(), 'StorageFailure: upsertAll failed');
    });

    test('cada tipo ofrece un mensaje en español para el usuario', () {
      const failures = <AppFailure>[
        PermissionFailure('permission-denied'),
        GalleryFailure('gallery-read-error'),
        StorageFailure('storage-write-error'),
        SyncFailure('sync-interrupted'),
        UnexpectedFailure('unclassified-error'),
      ];

      for (final failure in failures) {
        expect(failure.userMessage, isNotEmpty);
        // El mensaje de usuario nunca expone el mensaje técnico.
        expect(failure.userMessage, isNot(contains(failure.message)));
      }
    });
  });
}
