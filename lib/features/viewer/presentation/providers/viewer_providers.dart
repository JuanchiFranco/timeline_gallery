import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/media_asset.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:galeria_eventos/features/viewer/domain/viewer.dart';
import 'package:video_player/video_player.dart';

/// Assets entre los que se desliza el visor: los de un día (o los sin fecha),
/// del más reciente al más antiguo, igual que en el timeline.
///
/// La clave es el parámetro de fecha de la ruta (`2026-09-23` o `sin-fecha`);
/// el router ya descartó los inválidos.
final viewerAssetsProvider = Provider.autoDispose
    .family<AsyncValue<List<MediaAsset>>, String>((ref, dayParam) {
      final days = switch (ViewerDay.parse(dayParam)) {
        DatedViewerDay(:final date) => ref.watch(dayMomentsProvider(date)),
        _ => ref.watch(monthDaysProvider(const MonthKey.undated())),
      };
      return days.whenData(_flatten);
    });

List<MediaAsset> _flatten(List<TimelineDay> days) => [
  for (final day in days)
    for (final moment in day.moments) ...moment.assets,
];

/// Crea el controlador de reproducción de un archivo local. Los tests lo
/// reemplazan.
final videoControllerFactoryProvider =
    Provider<VideoPlayerController Function(String path)>(
      (ref) =>
          (path) => VideoPlayerController.file(File(path)),
    );
