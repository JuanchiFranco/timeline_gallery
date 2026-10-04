import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_grouping.dart';

/// Momentos de un día local. [date] es la medianoche local de ese día.
/// `autoDispose`: solo vive mientras la pantalla del día está abierta.
final dayMomentsProvider = StreamProvider.autoDispose
    .family<List<TimelineDay>, DateTime>((ref, date) {
      return ref
          .watch(mediaIndexRepositoryProvider)
          .watchRange(
            fromInclusive: DateTime(date.year, date.month, date.day).toUtc(),
            toExclusive: DateTime(date.year, date.month, date.day + 1).toUtc(),
          )
          .map(groupIntoDays);
    });
