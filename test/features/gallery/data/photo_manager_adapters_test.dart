import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/core/error/app_failure.dart';
import 'package:galeria_eventos/core/logging/app_logger.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_gallery_repository.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_media_file_repository.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_permission_service.dart';
import 'package:galeria_eventos/features/gallery/data/photo_manager_thumbnail_repository.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/gallery_permission.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';

import '../../../support/fakes.dart';
import '../../../support/photo_manager_channel.dart';

// Índices de `PermissionState` en el plugin.
const _denied = 2;
const _authorized = 3;
const _limited = 4;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger(enabled: false);
  late PhotoManagerChannel channel;

  setUp(() {
    channel = PhotoManagerChannel(binding)..install();
  });

  group('PhotoManagerPermissionService', () {
    late PhotoManagerPermissionService service;

    setUp(() => service = PhotoManagerPermissionService(logger));

    test('status consulta sin pedir permiso y traduce el estado', () async {
      channel.handlers['getPermissionState'] = (_) => _limited;

      expect(await service.status(), GalleryPermission.limited);

      expect(channel.callsTo('requestPermissionExtend'), isEmpty);
    });

    test('request muestra el diálogo y traduce el resultado', () async {
      channel.handlers['requestPermissionExtend'] = (_) => _authorized;

      expect(await service.request(), GalleryPermission.granted);
    });

    test('pide solo lectura y no pide la ubicación de las fotos', () async {
      channel.handlers['getPermissionState'] = (_) => _denied;

      await service.status();

      final args = channel.argsOf('getPermissionState');
      final android = args['androidPermission']! as Map<Object?, Object?>;
      expect(android['mediaLocation'], isFalse);
    });

    test('un error de plataforma es PermissionFailure y no filtra el '
        'mensaje original', () async {
      channel.handlers['getPermissionState'] = (_) => throw PlatformException(
        code: 'x',
        message: '/storage/emulated/0/DCIM/secreto.jpg',
      );

      await expectLater(
        service.status(),
        throwsA(
          isA<PermissionFailure>().having(
            (f) => f.userMessage + f.toString(),
            'texto visible',
            isNot(contains('secreto')),
          ),
        ),
      );
    });

    test(
      'abrir ajustes llega a la plataforma y ampliar la selección no falla',
      () async {
        channel.handlers['openSetting'] = (_) => null;

        await service.openSystemSettings();
        expect(channel.callsTo('openSetting'), hasLength(1));

        // `presentLimited` solo actúa en Android/iOS (el plugin lo ignora en
        // otras plataformas), así que desde el host solo se verifica que no
        // falla.
        await service.manageLimitedSelection();
      },
    );
  });

  group('PhotoManagerGalleryRepository', () {
    late FakeGalleryPermissionService permissions;
    late PhotoManagerGalleryRepository repository;

    setUp(() {
      permissions = FakeGalleryPermissionService(GalleryPermission.granted);
      repository = PhotoManagerGalleryRepository(permissions, logger);
    });

    test('sin permiso falla antes de tocar la galería', () async {
      permissions.current = GalleryPermission.denied;

      await expectLater(
        repository.totalCount(),
        throwsA(isA<PermissionFailure>()),
      );
      await expectLater(
        repository.readPage(page: 0, pageSize: 10),
        throwsA(isA<PermissionFailure>()),
      );

      expect(channel.callsTo('getAssetPathList'), isEmpty);
    });

    test('con acceso limitado sí lee', () async {
      permissions.current = GalleryPermission.limited;
      channel.handlers['getAssetPathList'] = (_) =>
          PhotoManagerChannel.pathList();
      channel.handlers['getAssetCountFromPath'] = (_) => 3;

      expect(await repository.totalCount(), 3);
    });

    test('totalCount cuenta sobre el álbum "todas"', () async {
      channel.handlers['getAssetPathList'] = (_) =>
          PhotoManagerChannel.pathList();
      channel.handlers['getAssetCountFromPath'] = (_) => 1234;

      expect(await repository.totalCount(), 1234);

      expect(channel.argsOf('getAssetPathList')['onlyAll'], isTrue);
    });

    test('una galería vacía da 0 y ninguna página', () async {
      // El plugin omite los álbumes sin assets.
      channel.handlers['getAssetPathList'] = (_) =>
          PhotoManagerChannel.pathList(assetCount: 0);

      expect(await repository.totalCount(), 0);
      expect(await repository.readPage(page: 0, pageSize: 10), isEmpty);
    });

    test('readPage convierte los assets de la plataforma', () async {
      channel.handlers['getAssetPathList'] = (_) =>
          PhotoManagerChannel.pathList();
      channel.handlers['getAssetListPaged'] = (_) => {
        'data': [
          PhotoManagerChannel.asset('a1'),
          PhotoManagerChannel.asset(
            'v1',
            type: 2,
            duration: 12,
            mimeType: 'video/mp4',
            createDt: 0,
          ),
        ],
      };

      final page = await repository.readPage(page: 2, pageSize: 50);

      expect(page, hasLength(2));
      expect(page[0].platformAssetId, 'a1');
      expect(page[0].type, MediaType.image);
      expect(page[0].captureDate, DateTime.utc(2026, 9, 21, 14, 13, 20));
      expect(page[0].captureDateSource, CaptureDateSource.captured);
      expect(page[1].type, MediaType.video);
      expect(page[1].durationMs, 12000);
      // Sin fecha de creación: cae a la de modificación.
      expect(page[1].captureDateSource, CaptureDateSource.modified);

      final args = channel.argsOf('getAssetListPaged');
      expect(args['page'], 2);
      expect(args['size'], 50);
    });

    test('pide el orden más reciente primero', () async {
      channel.handlers['getAssetPathList'] = (_) =>
          PhotoManagerChannel.pathList();
      channel.handlers['getAssetListPaged'] = (_) => {'data': <Object?>[]};

      await repository.readPage(page: 0, pageSize: 10);

      // Se inspecciona lo que viaja por el canal: el contrato del repositorio
      // promete descendente (asc: false) por fecha de creación (type: 0).
      final option = channel.argsOf('getAssetListPaged')['option'].toString();
      expect(option, contains('orders: [{type: 0, asc: false}]'));
    });

    test('no limita la fecha de creación a "hasta ahora": las fotos tomadas '
        'con la app abierta deben entrar', () async {
      channel.handlers['getAssetPathList'] = (_) =>
          PhotoManagerChannel.pathList();
      channel.handlers['getAssetListPaged'] = (_) => {'data': <Object?>[]};

      await repository.readPage(page: 0, pageSize: 10);

      final option = channel.argsOf('getAssetListPaged')['option'].toString();
      expect(option, matches(RegExp(r'createDate: \{[^}]*ignore: true')));
    });

    test(
      'un error de plataforma es GalleryFailure y no filtra la ruta',
      () async {
        channel.handlers['getAssetPathList'] = (_) =>
            throw PlatformException(code: 'boom', message: '/ruta/privada');

        await expectLater(
          repository.readPage(page: 0, pageSize: 10),
          throwsA(
            isA<GalleryFailure>().having(
              (f) => f.userMessage + f.toString(),
              'texto visible',
              isNot(contains('privada')),
            ),
          ),
        );
      },
    );
  });

  group('PhotoManagerThumbnailRepository', () {
    late PhotoManagerThumbnailRepository repository;
    final bytes = Uint8List.fromList([1, 2, 3]);

    setUp(() => repository = PhotoManagerThumbnailRepository(logger));

    Map<Object?, Object?> thumbOption() =>
        channel.argsOf('getThumb')['option']! as Map<Object?, Object?>;

    void stubAsset(Map<String, Object?> asset) {
      channel.handlers['fetchEntityProperties'] = (_) => asset;
      channel.handlers['getThumb'] = (_) => bytes;
    }

    test('la miniatura de grilla es cuadrada', () async {
      stubAsset(PhotoManagerChannel.asset('a1'));

      final result = await repository.load('a1', size: 300);

      expect(result, bytes);
      expect(thumbOption()['width'], 300);
      expect(thumbOption()['height'], 300);
    });

    test(
      'con preserveAspect conserva la proporción y reduce al lado largo',
      () async {
        stubAsset(PhotoManagerChannel.asset('a1'));

        await repository.load('a1', size: 2048, preserveAspect: true);

        // 4000x3000 -> 2048x1536.
        expect(thumbOption()['width'], 2048);
        expect(thumbOption()['height'], 1536);
      },
    );

    test('respeta la rotación del asset', () async {
      stubAsset(PhotoManagerChannel.asset('a1', orientation: 90));

      await repository.load('a1', size: 2048, preserveAspect: true);

      // Vertical en pantalla: 3000x4000 -> 1536x2048.
      expect(thumbOption()['width'], 1536);
      expect(thumbOption()['height'], 2048);
    });

    test('nunca amplía por encima del original', () async {
      stubAsset(PhotoManagerChannel.asset('a1', width: 1000, height: 500));

      await repository.load('a1', size: 2048, preserveAspect: true);

      expect(thumbOption()['width'], 1000);
      expect(thumbOption()['height'], 500);
    });

    test('un asset que ya no existe devuelve null', () async {
      channel.handlers['fetchEntityProperties'] = (_) => null;

      expect(await repository.load('borrado', size: 300), isNull);
      expect(channel.callsTo('getThumb'), isEmpty);
    });

    test('un fallo al generar la miniatura es GalleryFailure', () async {
      channel.handlers['fetchEntityProperties'] = (_) =>
          PhotoManagerChannel.asset('a1');
      channel.handlers['getThumb'] = (_) => throw PlatformException(code: 'x');

      await expectLater(
        repository.load('a1', size: 300),
        throwsA(isA<GalleryFailure>()),
      );
    });
  });

  group('PhotoManagerMediaFileRepository', () {
    // `AssetEntity.file` solo funciona en Android/iOS (usa dart:io Platform),
    // así que desde el host de tests solo se puede probar el caso sin asset.
    test('un asset que ya no existe no tiene ruta', () async {
      channel.handlers['fetchEntityProperties'] = (_) => null;

      final path = await PhotoManagerMediaFileRepository(
        logger,
      ).localPath('borrado');

      expect(path, isNull);
      expect(channel.callsTo('getFullFile'), isEmpty);
    });
  });
}
