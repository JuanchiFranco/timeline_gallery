import 'dart:async';

/// Limita la frecuencia de un stream: la primera emisión sale al instante y, si
/// llegan más dentro de [window], solo se entrega la última cuando la ventana
/// termina. Nunca se pierde el último valor: al cerrarse el origen se entrega
/// el pendiente.
///
/// Sirve para flujos que se disparan en ráfaga, como las consultas reactivas de
/// la base durante la primera sincronización (una emisión por página escrita):
/// sin esto la interfaz se reconstruiría cientos de veces con datos que dejan de
/// ser vigentes al instante.
///
/// Sin emisiones en ráfaga no deja ningún `Timer` vivo, así que no interfiere
/// con los tests de widgets.
extension ThrottleLatest<T> on Stream<T> {
  Stream<T> throttleLatest(Duration window) {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;
    DateTime? lastEmission;
    T? pending;
    var hasPending = false;

    void emit(T value) {
      lastEmission = DateTime.now();
      controller.add(value);
    }

    void flush() {
      timer = null;
      if (!hasPending) return;
      final value = pending as T;
      pending = null;
      hasPending = false;
      emit(value);
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          (value) {
            final last = lastEmission;
            final elapsed = last == null
                ? null
                : DateTime.now().difference(last);
            if (elapsed == null || elapsed >= window) {
              timer?.cancel();
              timer = null;
              hasPending = false;
              pending = null;
              emit(value);
              return;
            }
            pending = value;
            hasPending = true;
            timer ??= Timer(window - elapsed, flush);
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            flush();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        timer?.cancel();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
