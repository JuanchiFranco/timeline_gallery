# Decisiones técnicas

Registro corto de las decisiones tomadas y por qué. Se amplía en cada fase.

## Fase 2

**D1. Drift (SQLite) para el índice.** Mejor ajuste para consultas por rango
de fecha, índices compuestos y agrupación sobre decenas de miles de filas;
migraciones explícitas; ejecución en isolate de fondo. Isar quedó descartado
por el riesgo de continuidad del proyecto original.

**D2. Providers de Riverpod escritos a mano, sin `riverpod_generator`.** El
diseño original lo incluía. Se descartó para no sumar un segundo generador
sobre `build_runner` junto con `drift_dev` (ambos dependen de `analyzer`, y
resolver versiones compatibles es una fuente frecuente de fricción). La API
manual de Riverpod 3 es suficiente y el código generado no se puede revisar.

**D3. Sin `permission_handler`.** `photo_manager` (Fase 3) ya expone el estado
de permiso incluyendo acceso parcial/limitado.

**D4. Configuración por `--dart-define`, sin `flutter_dotenv`.** No hay
secretos ni nada que leer en runtime; `--dart-define-from-file=.env` acepta el
formato `.env` de forma nativa y evita una dependencia y un asset.

**D5. Providers de infraestructura en `core/di`** (no `app/di`): los consumen
las features y `core` no debe depender de `app`.

**D6. Fechas como instantes UTC con resolución de segundo.** Día y hora local
se calculan solo al presentar, así zona horaria y horario de verano no
afectan al orden ni a las consultas. Ráfagas en el mismo segundo se
desempatan por `id`.

**D7. `type` y `captureDateSource` se guardan como códigos enteros fijos**,
mapeados en la capa de datos: reordenar un enum del dominio no corrompe el
esquema.

**D8. `upsertAll` solo actualiza campos de plataforma.** `isFavorite` y
`createdAt` son estado local y sobreviven a la re-sincronización.

**D9. Modelo ampliado respecto al diseño:** `orientation` (requisito de
metadatos) y `captureDateSource` (marcar fechas inciertas). Se retiraron
`thumbnailReference` e `isSynced`: la miniatura se resuelve por
`platformAssetId` bajo demanda y el estado de sync vive en `SyncStateEntries`.

**D10. El código generado de drift (`*.g.dart`) se versiona**, para que
`flutter pub get && flutter run` funcione sin pasos extra.

**D11. Plugins nativos (`photo_manager`, `video_player`) se agregan en la
fase que los usa**, no antes.

## Fase 3

**D12. `photo_manager` para permisos y lectura.** Cubre MediaStore (Android) y
PhotoKit (iOS) con una sola API, expone el estado de permiso incluyendo
acceso limitado y pagina la lectura. Queda aislado en `features/gallery/data`
detrás de `GalleryPermissionService` y `DeviceGalleryRepository`: ni el
dominio ni la UI lo importan.

**D13. Mapeo de plataforma como función pura** (`mapPlatformAsset`). Toda la
lógica de fechas, ubicación y rotación se prueba sin plataforma. Reglas:
fecha de creación ausente o `0` → se usa la de modificación
(`CaptureDateSource.modified`); sin ninguna → época UTC
(`CaptureDateSource.unknown`); ubicación `0/0` → ausente; rotación →
múltiplo de 90 en `[0, 360)`. Limitación conocida: en Android `photo_manager`
ya cae a `DATE_ADDED` cuando falta `DATE_TAKEN`, y eso no es distinguible
desde Dart, así que `captured` puede incluir algunas fechas de importación.

**D14. No se pide `ACCESS_MEDIA_LOCATION`.** El timeline no necesita
coordenadas; no pedirlo reduce el permiso a lo mínimo y es coherente con el
"100% local". Si una fase futura agrupa por lugar, se pide entonces, con su
propia explicación al usuario.

**D15. El permiso se consulta con `getPermissionState` (sin diálogo)** y solo
se pide con `requestPermissionExtend` cuando el usuario toca "Conceder
acceso". Se relee al volver a la app (`AppLifecycleListener`), porque el
usuario pudo cambiarlo desde los ajustes del sistema.

## Fase 4

**D16. Sincronización completa + incremental por barrido ordenado.**
`photo_manager` no expone `MediaStore.getGeneration()`, así que no hay un
"qué cambió desde X" nativo. La incremental lee de lo más reciente a lo más
antiguo y se detiene en la primera página sin altas ni ediciones (compara
`platformAssetId` + `modifiedDate` contra el índice). La completa es la única
que ve todos los ids y por eso la única que detecta bajas.
`SyncStateKey.mediaStoreVersion/Generation` quedan reservadas por si se agrega
un canal nativo más adelante.

**D17. Escalado a completa.** Tras una incremental, si el total del
dispositivo no coincide con el del índice (bajas, o fotos antiguas que
entraron a la galería después) se hace una completa. Además hay una completa
cada 7 días para capturar ediciones antiguas que la incremental no alcanza.

**D18. Checkpoint por página.** El escaneo completo guarda la página siguiente
tras confirmar cada página, así una interrupción retoma sin repetir. Como un
escaneo retomado no vio las páginas previas, si al terminar el total no cuadra
se repite desde cero para detectar bajas. El checkpoint "vacío" significa sin
escaneo pendiente (el store no borra claves sueltas).

**D19. El servicio de sync es dominio puro** (`DeviceGalleryRepository`,
`MediaIndexRepository`, `SyncStateStore` inyectados) y no solapa ejecuciones:
llamadas simultáneas comparten el mismo `Future`. Se dispara al obtener
permiso de lectura y al volver a la app.

## Fase 5

**D20. Meses cargados bajo demanda.** La UI solo recibe de entrada la lista de
meses con su conteo (`watchMonthBuckets`, un `GROUP BY` sobre el índice). Cada
mes consulta su propio rango cuando el `ListView.builder` lo construye
(`monthDaysProvider`, `autoDispose`), así 50 000 assets no se cargan de golpe y
durante una sincronización solo los meses visibles reconsultan.

**D21. Zona horaria coherente entre SQL y Dart.** El mes se agrupa en SQL con
`strftime(..., 'localtime')` y el rango de cada mes se calcula en Dart con
`DateTime(año, mes).toUtc()`. Ambos usan la zona del dispositivo, así el conteo
de un mes y las filas que devuelve su rango coinciden (hay un test que lo
verifica en los bordes del mes). El día y el momento se calculan solo en Dart,
al presentar (D6).

**D22. Momento = hueco de hasta 90 minutos dentro de un día local.** Un
momento nunca cruza la medianoche. El umbral es un parámetro de
`groupIntoDays`; 90 min es un punto de partida a ajustar con galerías reales.

**D23. Assets sin fecha confiable van a un grupo "Sin fecha"** al final, con un
único momento y sin hora: su orden no significa nada. Es el mismo bucket
(`capture_date_source = 2`) en SQL y en la agrupación.

**D24. Miniaturas como `ImageProvider` propio** (`ThumbnailImage`), con clave
(id, tamaño). Así el `ImageCache` de Flutter evita repetir llamadas a la
plataforma al hacer scroll, y el widget usa `Image` con `errorBuilder` para
assets que ya no existen. No se cachea en disco: el sistema ya mantiene su
caché de miniaturas.

**D25. Máximo de 8 miniaturas por momento** (2 filas de 4); el resto se resume
como "+N". Ver todo el momento es responsabilidad del visor (Fase 7).

**D26. Fechas en español sin `intl`** (`EsDateFormat`), porque la app solo está
en español por ahora. Si se agrega otro idioma, migrar a `intl`.

## Fase 6

**D27. El calendario reutiliza `monthDaysProvider`.** Cada página del mes lee
los mismos días ya agrupados que el timeline y deriva de ahí la portada y el
conteo de cada día (`summarizeDays`). No hay una consulta nueva ni lógica de
agrupación duplicada; abrir un mes cuesta lo mismo en las dos pestañas.

**D28. Un `PageView` con todos los meses entre el más antiguo y el más
reciente con recuerdos**, sin huecos (`calendarMonths`), para que las flechas
nunca salten un mes. Los meses vacíos del medio se muestran con la grilla sin
portadas. Al llegar meses antiguos durante una sincronización, los índices se
corren: la página recuerda el `MonthKey` visible y vuelve a él.

**D29. Semana desde el lunes** (convención del idioma de la app). La grilla
rellena con huecos para tener siempre semanas completas.

**D30. El día es una ruta hija de Calendario** (`/calendar/day/2026-09-23`),
con el parámetro validado (`2026-02-31` es inválido; `DateTime` lo desbordaría
al 3 de marzo). Muestra todos los momentos con slivers perezosos y sin el tope
de 8 miniaturas del timeline. Una fecha inválida muestra un aviso en vez de
fallar.

**D31. Tocar una miniatura todavía no hace nada**; el visor llega en la Fase 7.

## Fase 7

**D32. `video_player` para la reproducción** (agregado en esta fase, como
fijó D11). En los tests se sustituye la plataforma con un
`VideoPlayerPlatform` en memoria (`video_player_platform_interface` como
dependencia de desarrollo), sin decodificar nada.

**D33. El visor navega entre los assets de un día**, no entre una lista pasada
por parámetro. La ruta es `/viewer/<día>/<id>` (`2026-09-23` o `sin-fecha`):
se puede abrir con un enlace directo, sobrevive a un reinicio de la ruta y el
orden coincide con el del timeline. Los ids van codificados porque los
`localIdentifier` de iOS contienen `/`. Es una ruta de primer nivel, fuera del
shell, para ocupar toda la pantalla.

**D34. Las fotos se muestran como vista previa de hasta 2048 px**, no como el
original. El original puede pesar decenas de MB y no siempre lo decodifica
Flutter (HEIC en Android); la vista previa la genera la plataforma en un
formato seguro y conserva la proporción (`preserveAspect`). Si hace falta
máxima calidad con zoom profundo, es una mejora futura.

**D35. Zoom con `InteractiveViewer`** (pellizco y doble toque). Mientras hay
zoom el `PageView` deja de deslizar, para que arrastrar mueva la imagen y no
cambie de asset.

**D36. El video muestra un póster y solo crea el reproductor al tocar
reproducir.** Pasar por varios videos seguidos no abre varios decodificadores.
La página libera el controlador al salir de ella. Se descubrió que
`VideoPlayerController.dispose()` no termina nunca si la creación falló (espera
un completer que nunca se completa), por eso la limpieza tras un error no se
espera.

**D37. Si el asset abierto ya no existe** (se borró mientras tanto) se abre el
primero del día; y si cambia la lista durante una sincronización, la página
sigue en el asset que se estaba viendo (mismo criterio que el calendario).

Pendiente para fases siguientes: marcar favoritos desde el visor, compartir y
borrar (el borrado del dispositivo es una acción destructiva que requiere su
propio diseño y confirmación).
