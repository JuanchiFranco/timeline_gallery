import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_image.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_picture.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_queue.dart';

import '../../../support/fakes.dart';

/// Miniaturas que nunca están disponibles y cuentan cuántas veces se pidieron.
class _CountingThumbnails extends FakeThumbnailRepository {
  int calls = 0;

  @override
  Future<Uint8List?> load(
    String platformAssetId, {
    required int size,
    bool preserveAspect = false,
  }) {
    calls++;
    return super.load(
      platformAssetId,
      size: size,
      preserveAspect: preserveAspect,
    );
  }
}

/// Resuelve [provider] y espera a que falle.
Future<void> _resolveUntilError(
  WidgetTester tester,
  ThumbnailImage provider,
) async {
  final failed = Completer<void>();
  provider
      .resolve(ImageConfiguration.empty)
      .addListener(
        ImageStreamListener(
          (_, _) {},
          onError: (error, stack) => failed.complete(),
        ),
      );
  await tester.runAsync(() => failed.future);
  // El desalojo se programa en un microtask tras el fallo.
  await tester.pump();
}

void main() {
  group('ThumbnailImage: las cargas fallidas no quedan en el caché', () {
    testWidgets('una miniatura no disponible se desaloja', (tester) async {
      final repository = _CountingThumbnails();
      final provider = ThumbnailImage(
        repository: repository,
        assetId: 'a',
        size: 300,
      );

      await _resolveUntilError(tester, provider);

      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
      );
    });

    testWidgets('al volver a pedirla se reintenta en vez de repetir el '
        'fallo cacheado', (tester) async {
      final repository = _CountingThumbnails();
      final provider = ThumbnailImage(
        repository: repository,
        assetId: 'a',
        size: 300,
      );

      await _resolveUntilError(tester, provider);
      await _resolveUntilError(tester, provider);

      expect(repository.calls, 2);
    });

    testWidgets('una carga que la cola descartó también se desaloja y nunca '
        'llega a la plataforma', (tester) async {
      final repository = _CountingThumbnails();
      final queue = ThumbnailQueue(); // sin interés registrado
      final provider = ThumbnailImage(
        repository: repository,
        assetId: 'a',
        size: 300,
        queue: queue,
      );

      await _resolveUntilError(tester, provider);

      expect(repository.calls, 0);
      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
      );
    });
  });

  group('ThumbnailPicture y la cola', () {
    late ThumbnailQueue queue;
    late _CountingThumbnails repository;

    setUp(() {
      queue = ThumbnailQueue();
      repository = _CountingThumbnails();
    });

    Widget host(Widget child) => ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        thumbnailQueueProvider.overrideWithValue(queue),
        thumbnailRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: child),
    );

    ThumbnailPicture picture(String id) => ThumbnailPicture(
      assetId: id,
      size: 300,
      fallback: const Icon(Icons.image_outlined),
    );

    String key(String id) => ThumbnailImage.keyFor(assetId: id, size: 300);

    testWidgets('declara su interés al montarse y lo retira al salir', (
      tester,
    ) async {
      await tester.pumpWidget(host(picture('a')));
      expect(queue.isWanted(key('a')), isTrue);

      await tester.pumpWidget(host(const SizedBox()));
      expect(queue.isWanted(key('a')), isFalse);
    });

    testWidgets('si cambia el asset, mueve el interés a la nueva clave', (
      tester,
    ) async {
      await tester.pumpWidget(host(picture('a')));
      await tester.pumpWidget(host(picture('b')));

      expect(queue.isWanted(key('a')), isFalse);
      expect(queue.isWanted(key('b')), isTrue);
    });

    testWidgets('dos celdas con el mismo asset comparten interés', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(Column(children: [picture('a'), picture('a')])),
      );
      await tester.pumpWidget(host(Column(children: [picture('a')])));

      expect(queue.isWanted(key('a')), isTrue, reason: 'queda una celda');
    });

    testWidgets('muestra el reemplazo cuando la miniatura no está disponible', (
      tester,
    ) async {
      await tester.pumpWidget(host(picture('a')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });
}
