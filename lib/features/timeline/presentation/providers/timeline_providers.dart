import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_grouping.dart';

/// Meses con recuerdos, del más reciente al más antiguo. Es lo único que se
/// carga de entrada: el contenido de cada mes se pide cuando se muestra.
final monthBucketsProvider = StreamProvider<List<MonthBucket>>(
  (ref) => ref.watch(mediaIndexRepositoryProvider).watchMonthBuckets(),
);

/// Días y momentos de un mes. `autoDispose` para que solo los meses visibles
/// mantengan una consulta reactiva abierta mientras se sincroniza.
final monthDaysProvider = StreamProvider.autoDispose
    .family<List<TimelineDay>, MonthKey>((ref, month) {
      return ref
          .watch(mediaIndexRepositoryProvider)
          .watchRange(fromInclusive: month.startUtc, toExclusive: month.endUtc)
          .map(groupIntoDays);
    });
