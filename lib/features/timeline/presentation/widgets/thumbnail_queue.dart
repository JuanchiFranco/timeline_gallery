import 'dart:async';

/// Se lanza cuando una carga se descarta porque nadie la necesita ya.
class ThumbnailCancelled implements Exception {
  const ThumbnailCancelled();
}

/// Cola de cargas de miniaturas con concurrencia acotada.
///
/// Un scroll rápido construye cientos de celdas en segundos. Sin esta cola,
/// cada una dispara su carga a la plataforma de inmediato: decenas de lecturas
/// simultáneas, la mayoría para celdas que ya salieron de pantalla.
///
/// * **Concurrencia acotada** ([concurrency]): la plataforma no se satura.
/// * **Lo más reciente primero** (LIFO): al hacer scroll, lo que acaba de
///   aparecer es lo que el usuario está mirando.
/// * **Se descarta lo que ya no se mira**: cada celda declara su interés con
///   [addInterest] al montarse y lo retira con [removeInterest] al
///   desmontarse; una carga cuya clave ya no tiene interés se cancela sin
///   llegar a la plataforma.
class ThumbnailQueue {
  ThumbnailQueue({this.concurrency = 4}) : assert(concurrency > 0);

  final int concurrency;

  final Map<String, int> _interest = {};
  final List<_Runnable> _pending = [];
  int _running = 0;

  /// Cargas en curso (para pruebas y diagnóstico).
  int get running => _running;

  /// Cargas esperando su turno (para pruebas y diagnóstico).
  int get pending => _pending.length;

  void addInterest(String key) =>
      _interest.update(key, (n) => n + 1, ifAbsent: () => 1);

  void removeInterest(String key) {
    final count = _interest[key];
    if (count == null) return;
    if (count <= 1) {
      _interest.remove(key);
    } else {
      _interest[key] = count - 1;
    }
  }

  bool isWanted(String key) => _interest.containsKey(key);

  /// Ejecuta [job] cuando haya un cupo libre. Falla con [ThumbnailCancelled] si
  /// al llegar su turno la clave ya no tiene interés.
  Future<T> run<T>(String key, Future<T> Function() job) {
    final entry = _Job<T>(key, job);
    _pending.add(entry);
    _pump();
    return entry.completer.future;
  }

  void _pump() {
    while (_running < concurrency && _pending.isNotEmpty) {
      final next = _pending.removeLast();
      if (!isWanted(next.key)) {
        next.cancel();
        continue;
      }
      _running++;
      next.start().whenComplete(() {
        _running--;
        _pump();
      });
    }
  }
}

class _Job<T> implements _Runnable {
  _Job(this.key, this._job);

  @override
  final String key;
  final Future<T> Function() _job;
  final Completer<T> completer = Completer<T>();

  @override
  void cancel() => completer.completeError(const ThumbnailCancelled());

  @override
  Future<void> start() async {
    try {
      completer.complete(await _job());
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }
}

abstract interface class _Runnable {
  String get key;
  void cancel();
  Future<void> start();
}
