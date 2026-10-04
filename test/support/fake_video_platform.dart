import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Plataforma de video en memoria: todo sucede al instante y no decodifica
/// nada. Registra los archivos abiertos para poder verificarlos.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> openedUris = [];
  final Set<int> playing = {};
  int _nextId = 1;

  /// Si es `true`, `createWithOptions` falla como un archivo ilegible.
  bool failToCreate = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    playing.remove(playerId);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (failToCreate) throw StateError('cannot open video');
    openedUris.add(options.dataSource.uri ?? '');
    return _nextId++;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 12),
      size: const Size(1920, 1080),
    ),
  );

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => playing.add(playerId);

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      buildView(options.playerId);
}
