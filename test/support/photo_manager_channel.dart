import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channelName = 'com.fluttercandies/photo_manager';

/// Plataforma de `photo_manager` simulada a nivel de canal: así los
/// adaptadores se prueban con el código real del plugin (serialización de
/// opciones, conversión de respuestas) y no solo con fakes de nuestras
/// interfaces.
///
/// Cada método se configura en [handlers]; si alguno no está, el canal
/// responde "no implementado" y el test falla con un mensaje claro.
class PhotoManagerChannel {
  PhotoManagerChannel(this.binding);

  final TestWidgetsFlutterBinding binding;

  /// Respuesta por nombre de método. Puede lanzar `PlatformException`.
  final Map<String, Object? Function(Map<Object?, Object?> args)> handlers = {};

  /// Llamadas recibidas, en orden.
  final List<MethodCall> calls = [];

  void install() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(_channelName),
      (call) async {
        calls.add(call);
        final handler = handlers[call.method];
        if (handler == null) {
          throw MissingPluginException('unmocked ${call.method}');
        }
        final raw = call.arguments;
        return handler(raw is Map ? raw.cast<Object?, Object?>() : const {});
      },
    );
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(_channelName),
        null,
      ),
    );
  }

  Iterable<MethodCall> callsTo(String method) =>
      calls.where((c) => c.method == method);

  /// Argumentos de la única llamada a [method].
  Map<Object?, Object?> argsOf(String method) =>
      callsTo(method).single.arguments as Map<Object?, Object?>;

  /// Mapa de un asset como lo entrega la plataforma.
  static Map<String, Object?> asset(
    String id, {
    int type = 1,
    int width = 4000,
    int height = 3000,
    int? createDt = 1790000000,
    int? modifiedDt = 1790000500,
    int duration = 0,
    int orientation = 0,
    double? lat,
    double? lng,
    String? mimeType = 'image/jpeg',
  }) => {
    'id': id,
    'type': type,
    'width': width,
    'height': height,
    'duration': duration,
    'orientation': orientation,
    'createDt': createDt,
    'modifiedDt': modifiedDt,
    'lat': lat,
    'lng': lng,
    'mimeType': mimeType,
  };

  /// Lista de álbumes con el álbum "todas".
  static Map<String, Object?> pathList({int assetCount = 3}) => {
    'data': [
      {
        'id': 'all',
        'name': 'Recent',
        'isAll': true,
        'assetCount': assetCount,
        'albumType': 1,
      },
    ],
  };
}
