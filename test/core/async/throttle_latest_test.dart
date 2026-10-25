// Los controladores de origen de cada caso se descartan al terminar el test.
// ignore_for_file: close_sinks

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/async/throttle_latest.dart';

void main() {
  const window = Duration(milliseconds: 300);

  /// Corre [body] con un origen controlable y devuelve lo que recibió el
  /// oyente, con el reloj simulado.
  List<int> run(
    void Function(StreamController<int> source, FakeAsync async) body,
  ) {
    final received = <int>[];
    fakeAsync((async) {
      final source = StreamController<int>();
      source.stream.throttleLatest(window).listen(received.add);
      body(source, async);
      source.close();
      async.flushMicrotasks();
    });
    return received;
  }

  test('la primera emisión sale al instante', () {
    final received = run((source, async) {
      source.add(1);
      async.flushMicrotasks();
    });

    expect(received, [1]);
  });

  test('una ráfaga entrega el primero y luego solo el último', () {
    final received = <int>[];
    List<int>? midWindow;
    fakeAsync((async) {
      final source = StreamController<int>();
      source.stream.throttleLatest(window).listen(received.add);
      source
        ..add(1)
        ..add(2)
        ..add(3)
        ..add(4);
      async.flushMicrotasks();
      midWindow = List.of(received);

      async.elapse(window);
      source.close();
      async.flushMicrotasks();
    });

    expect(midWindow, [1], reason: 'a mitad de ventana solo salió el primero');
    expect(received, [1, 4]);
  });

  test('pasada la ventana, la siguiente vuelve a salir al instante', () {
    final received = run((source, async) {
      source.add(1);
      async.elapse(window * 2);
      source.add(2);
      async.flushMicrotasks();
    });

    expect(received, [1, 2]);
  });

  test('al cerrarse el origen entrega el valor pendiente y cierra', () async {
    // Tiempo real: el cierre del stream de salida no se observa bien bajo el
    // reloj simulado de `fakeAsync`.
    final result = await Stream.fromIterable([
      1,
      2,
      3,
    ]).throttleLatest(const Duration(milliseconds: 50)).toList();

    expect(result, [1, 3]);
  });

  test('un solo valor no deja ningún Timer vivo', () {
    fakeAsync((async) {
      final source = StreamController<int>();
      source.stream.throttleLatest(window).listen((_) {});
      source.add(1);
      async.flushMicrotasks();

      expect(async.pendingTimers, isEmpty);
    });
  });

  test('cancelar la suscripción cancela el Timer pendiente', () {
    fakeAsync((async) {
      final source = StreamController<int>();
      final subscription = source.stream.throttleLatest(window).listen((_) {});
      source
        ..add(1)
        ..add(2);
      async.flushMicrotasks();
      expect(async.pendingTimers, hasLength(1));

      subscription.cancel();
      async.flushMicrotasks();

      expect(async.pendingTimers, isEmpty);
    });
  });

  test('los errores del origen se reenvían', () {
    final errors = <Object>[];
    fakeAsync((async) {
      final source = StreamController<int>();
      source.stream.throttleLatest(window).listen((_) {}, onError: errors.add);
      source.addError(StateError('x'));
      async.flushMicrotasks();
    });

    expect(errors.single, isA<StateError>());
  });
}
