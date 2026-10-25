import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/widgets/error_state.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('muestra el mensaje del AppFailure, nunca el técnico', (
    tester,
  ) async {
    const failure = StorageFailure('SQLITE_FULL en /data/user/0/db');

    await tester.pumpWidget(_wrap(const ErrorState(error: failure)));

    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.text(failure.userMessage), findsOneWidget);
    expect(find.textContaining('SQLITE'), findsNothing);
  });

  testWidgets('un error desconocido muestra el mensaje genérico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ErrorState(error: StateError('/ruta/privada'))),
    );

    expect(find.text(const UnexpectedFailure('x').userMessage), findsOneWidget);
    expect(find.textContaining('privada'), findsNothing);
  });

  testWidgets('sin onRetry no hay botón', (tester) async {
    await tester.pumpWidget(_wrap(const ErrorState(error: SyncFailure('x'))));

    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('con onRetry el botón lo invoca', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _wrap(
        ErrorState(error: const SyncFailure('x'), onRetry: () => retries++),
      ),
    );

    await tester.tap(find.text('Reintentar'));

    expect(retries, 1);
  });

  test('userMessageFor distingue AppFailure de cualquier otro error', () {
    expect(
      userMessageFor(const PermissionFailure('x')),
      const PermissionFailure('y').userMessage,
    );
    expect(
      userMessageFor(Exception('x')),
      const UnexpectedFailure('y').userMessage,
    );
  });
}
