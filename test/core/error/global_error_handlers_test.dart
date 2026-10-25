import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/error/global_error_handlers.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';

void main() {
  late List<LogRecord> records;
  late AppLogger logger;
  late void Function(FlutterErrorDetails)? originalOnError;
  late ErrorWidgetBuilder originalBuilder;
  late ui.PlatformDispatcher dispatcher;
  late bool Function(Object, StackTrace)? originalDispatcherOnError;

  setUp(() {
    records = [];
    logger = AppLogger(enabled: true, sink: records.add);
    originalOnError = FlutterError.onError;
    originalBuilder = ErrorWidget.builder;
    TestWidgetsFlutterBinding.ensureInitialized();
    dispatcher = ui.PlatformDispatcher.instance;
    originalDispatcherOnError = dispatcher.onError;
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    ErrorWidget.builder = originalBuilder;
    dispatcher.onError = originalDispatcherOnError;
  });

  test('registra los errores del framework sin romper el manejador previo', () {
    var previousCalled = false;
    FlutterError.onError = (_) => previousCalled = true;
    installGlobalErrorHandlers(logger, dispatcher: dispatcher);

    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('/storage/emulated/0/DCIM/secreto.jpg'),
        stack: StackTrace.current,
      ),
    );

    expect(previousCalled, isTrue);
    expect(records, hasLength(1));
    expect(records.single.tag, LogTag.ui);
    expect(records.single.level, LogLevel.error);
    // Solo el tipo: nunca el contenido de la excepción.
    expect(records.single.errorType, 'StateError');
    expect(records.single.message, isNot(contains('secreto')));
  });

  test('registra los errores asíncronos y los da por manejados', () {
    installGlobalErrorHandlers(logger, dispatcher: dispatcher);

    final handled = dispatcher.onError!(ArgumentError('x'), StackTrace.current);

    expect(handled, isTrue);
    expect(records.single.errorType, 'ArgumentError');
    expect(records.single.message, contains('async'));
  });

  test('con el logger desactivado (producción) no escribe nada', () {
    installGlobalErrorHandlers(
      AppLogger(enabled: false, sink: records.add),
      dispatcher: dispatcher,
    );

    dispatcher.onError!(StateError('x'), StackTrace.current);

    expect(records, isEmpty);
  });

  test('solo reemplaza el widget de error si se pide', () {
    installGlobalErrorHandlers(logger, dispatcher: dispatcher);
    expect(identical(ErrorWidget.builder, originalBuilder), isTrue);

    installGlobalErrorHandlers(
      logger,
      dispatcher: dispatcher,
      replaceErrorWidget: true,
    );
    final widget = ErrorWidget.builder(
      FlutterErrorDetails(exception: StateError('x')),
    );
    expect(widget, isA<FallbackErrorWidget>());
  });

  testWidgets('el aviso de reemplazo se dibuja sin Theme ni Directionality', (
    tester,
  ) async {
    await tester.pumpWidget(const FallbackErrorWidget());

    expect(find.text('No pudimos mostrar esto'), findsOneWidget);
  });
}
