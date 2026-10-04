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
}
