import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_queue.dart';

/// Un trabajo que queda en curso hasta que el test lo libera.
class _Gate {
  _Gate(this.queue, this.key) {
    queue.addInterest(key);
    result = queue.run<String>(key, () {
      started = true;
      return release.future;
    });
  }

  final ThumbnailQueue queue;
  final String key;
  final Completer<String> release = Completer<String>();
  late final Future<String> result;
  bool started = false;
}

void main() {
  test('no supera la concurrencia máxima', () async {
    final queue = ThumbnailQueue(concurrency: 2);
    final gates = [for (var i = 0; i < 5; i++) _Gate(queue, 'k$i')];

    expect(queue.running, 2);
    expect(queue.pending, 3);
    expect(gates.where((g) => g.started), hasLength(2));

    // Al liberar uno, entra el siguiente: nunca hay más de 2 a la vez.
    gates.firstWhere((g) => g.started).release.complete('ok');
    await pumpEventQueue();
    expect(queue.running, 2);
    expect(queue.pending, 2);
  });

  test('atiende primero lo más reciente', () async {
    final queue = ThumbnailQueue(concurrency: 1);
    final order = <String>[];
    final first = _Gate(queue, 'primero'); // ocupa el único cupo
    for (final key in ['a', 'b', 'c']) {
      queue.addInterest(key);
      unawaited(queue.run<void>(key, () async => order.add(key)));
    }

    first.release.complete('x');
    await pumpEventQueue();

    expect(order, ['c', 'b', 'a']);
  });

  test('descarta lo que ya nadie mira, sin llegar a ejecutarlo', () async {
    final queue = ThumbnailQueue(concurrency: 1);
    final busy = _Gate(queue, 'ocupado');
    var executed = false;
    queue.addInterest('visible');
    queue.addInterest('fuera');
    final dropped = queue.run<void>('fuera', () async => executed = true);
    final kept = queue.run<void>('visible', () async {});
    // La celda 'fuera' sale de pantalla antes de que le toque.
    queue.removeInterest('fuera');

    busy.release.complete('x');
    await kept;

    await expectLater(dropped, throwsA(isA<ThumbnailCancelled>()));
    expect(executed, isFalse);
  });

  test('el interés se cuenta: dos celdas con la misma clave', () async {
    final queue = ThumbnailQueue()
      ..addInterest('k')
      ..addInterest('k');

    queue.removeInterest('k');
    expect(queue.isWanted('k'), isTrue, reason: 'queda otra celda mirándola');

    queue.removeInterest('k');
    expect(queue.isWanted('k'), isFalse);

    // Retirar de más no deja contadores negativos ni falla.
    queue.removeInterest('k');
    expect(queue.isWanted('k'), isFalse);
  });

  test('un fallo se propaga a quien lo pidió y no frena la cola', () async {
    final queue = ThumbnailQueue(concurrency: 1)
      ..addInterest('mala')
      ..addInterest('buena');
    final bad = queue.run<void>('mala', () async => throw StateError('x'));
    final good = queue.run<String>('buena', () async => 'ok');

    await expectLater(bad, throwsA(isA<StateError>()));
    expect(await good, 'ok');
    expect(queue.running, 0);
  });

  test('entrega el resultado de cada trabajo', () async {
    final queue = ThumbnailQueue()
      ..addInterest('a')
      ..addInterest('b');

    final results = await Future.wait([
      queue.run<int>('a', () async => 1),
      queue.run<int>('b', () async => 2),
    ]);

    expect(results, [1, 2]);
  });
}
