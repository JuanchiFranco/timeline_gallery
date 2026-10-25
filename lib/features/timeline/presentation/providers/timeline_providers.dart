import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/core/async/throttle_latest.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/day_bucket.dart';
import 'package:galeria_eventos/features/gallery/domain/entities/month_bucket.dart';
import 'package:galeria_eventos/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_grouping.dart';
import 'package:galeria_eventos/features/timeline/domain/timeline_rows.dart';
import 'package:galeria_eventos/features/timeline/presentation/widgets/thumbnail_queue.dart';

/// Ventana mínima entre actualizaciones del resumen por día. Durante la
/// primera sincronización la base emite una vez por página escrita; sin esto la
/// lista se reconstruiría cientos de veces con datos que quedan viejos al
/// instante.
const _summaryThrottle = Duration(milliseconds: 300);

/// Un resumen por día de todo el índice (cantidad y portada). Es lo único que
/// se carga de entrada: alimenta la lista del timeline y el calendario, y los
/// assets de cada día se piden solo cuando ese día aparece en pantalla.
final dayBucketsProvider = StreamProvider<List<DayBucket>>(
  (ref) => ref
      .watch(mediaIndexRepositoryProvider)
      .watchDayBuckets()
      .throttleLatest(_summaryThrottle),
);

/// Meses con recuerdos, derivados del resumen por día.
final monthBucketsProvider = Provider<AsyncValue<List<MonthBucket>>>(
  (ref) => ref.watch(dayBucketsProvider).whenData(monthBucketsFrom),
);

/// Filas de la lista del timeline.
final timelineRowsProvider = Provider<AsyncValue<List<TimelineRow>>>(
  (ref) => ref.watch(dayBucketsProvider).whenData(buildTimelineRows),
);

/// Los assets sin fecha confiable, agrupados. `autoDispose` para que solo viva
/// mientras se muestra.
final undatedDaysProvider = StreamProvider.autoDispose<List<TimelineDay>>((
  ref,
) {
  const undated = MonthKey.undated();
  return ref
      .watch(mediaIndexRepositoryProvider)
      .watchRange(fromInclusive: undated.startUtc, toExclusive: undated.endUtc)
      .map(groupIntoDays);
});

/// Momentos de un día local. [date] es la medianoche local de ese día.
/// `autoDispose`: solo vive mientras el día está en pantalla, así que durante
/// una sincronización solo los días visibles mantienen una consulta abierta.
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

/// Altura real que tuvo cada día la última vez que se construyó. La lista es
/// perezosa y los días fuera de pantalla se destruyen; al volver a ellos, esta
/// altura evita que el contenido salte mientras se vuelven a cargar.
final dayHeightCacheProvider = Provider<Map<DateTime, double>>((ref) => {});

/// Cola que acota y prioriza la carga de miniaturas de las grillas.
final thumbnailQueueProvider = Provider<ThumbnailQueue>(
  (ref) => ThumbnailQueue(),
);
