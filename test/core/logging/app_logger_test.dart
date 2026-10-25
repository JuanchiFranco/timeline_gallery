import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';

void main() {
  test('con enabled=false no emite ningún registro', () {
    final records = <LogRecord>[];
    final logger = AppLogger(enabled: false, sink: records.add);

    logger
      ..debug(LogTag.ui, 'a')
      ..info(LogTag.platform, 'b')
      ..warning(LogTag.database, 'c')
      ..error(LogTag.gallerySync, 'd', error: StateError('x'));

    expect(records, isEmpty);
  });

  test('con enabled=true emite etiqueta, nivel y mensaje', () {
    final records = <LogRecord>[];
    final logger = AppLogger(enabled: true, sink: records.add);

    logger.info(LogTag.galleryRepository, 'batch 3/10');

    expect(records, hasLength(1));
    expect(records.single.tag, LogTag.galleryRepository);
    expect(records.single.level, LogLevel.info);
    expect(records.single.message, 'batch 3/10');
  });

  test('del error solo registra el tipo, nunca su contenido', () {
    final records = <LogRecord>[];
    final logger = AppLogger(enabled: true, sink: records.add);

    logger.error(
      LogTag.database,
      'query failed',
      error: const FormatException('/storage/emulated/0/DCIM/private.jpg'),
    );

    final record = records.single;
    expect(record.errorType, 'FormatException');
    expect(record.message, isNot(contains('private.jpg')));
  });

  test('cada método usa su nivel', () {
    final records = <LogRecord>[];
    AppLogger(enabled: true, sink: records.add)
      ..debug(LogTag.ui, 'd')
      ..info(LogTag.ui, 'i')
      ..warning(LogTag.ui, 'w', error: ArgumentError('x'))
      ..error(LogTag.ui, 'e');

    expect(records.map((r) => r.level), [
      LogLevel.debug,
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
    ]);
    expect(records[2].errorType, 'ArgumentError');
    expect(records[3].errorType, isNull);
  });

  test('los niveles son compatibles con dart:developer (ascendentes)', () {
    final values = LogLevel.values.map((l) => l.value).toList();

    expect(values, [...values]..sort());
    expect(LogLevel.error.value, 1000);
  });

  test('sin sink usa la salida por defecto y no falla', () {
    final logger = AppLogger(enabled: true);

    expect(
      () => logger
        ..info(LogTag.ui, 'solo mensaje')
        ..error(
          LogTag.ui,
          'con error',
          error: StateError('x'),
          stackTrace: StackTrace.current,
        ),
      returnsNormally,
    );
  });
}
