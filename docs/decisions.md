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

## Fase 8

**D38. Los adaptadores de `photo_manager` se prueban a nivel de canal**
(`test/support/photo_manager_channel.dart`), no con un fake de nuestras
interfaces: así corre el código real del plugin (serialización de opciones,
conversión de respuestas) y se ve lo que de verdad viaja a la plataforma. Límite
conocido: `AssetEntity.file` y `presentLimited` solo actúan en Android/iOS
(usan `dart:io Platform`), por lo que esos dos caminos solo se ejercitan en
dispositivo.

**D39. Bug corregido: el filtro de lectura ya no congela "ahora".** El filtro
por defecto de `photo_manager` acota la fecha de creación a "hasta ahora", y
ese instante se fija al construirlo. Como `static final`, las fotos tomadas
*después* de abrir la app quedaban fuera de toda sincronización hasta
reiniciarla. Ahora se construye en cada lectura y se ignora el rango de fechas;
queda cubierto por un test sobre lo que viaja por el canal.

**D40. Fechas plausibles.** Una fecha de captura solo se acepta entre
1990-01-01 y mañana (margen de un día por husos). Fuera de eso (relojes sin
configurar, 1970/1980, o adelantados) se usa la fecha de modificación si es
plausible, y si no, el asset queda "sin fecha". Evita una foto "de 2099" al tope
del timeline y un calendario de cientos de meses. La marca de modificación
(`modifiedDate`) se conserva cruda: es solo un indicador de cambio.

**D41. `mappingVersion` fuerza un re-escaneo cuando cambian las reglas de
interpretación.** La sincronización incremental no vuelve a mirar lo que no
cambió, así que lo ya indexado conservaría el resultado de las reglas
anteriores. Subir `DefaultGallerySyncService.mappingVersion` (historial en su
documentación) hace que la siguiente sincronización sea completa.

**D42. Errores globales registrados, no perdidos.**
`installGlobalErrorHandlers` engancha `FlutterError.onError` y
`PlatformDispatcher.onError` y registra solo el *tipo* del error (regla de
privacidad del logger). En release se reemplaza la pantalla roja/gris por un
aviso discreto (`FallbackErrorWidget`). `main` crea el `ProviderContainer`
para instalarlos antes de construir la UI.

**D43. Todo error de pantalla ofrece "Reintentar"** (`ErrorState`): permiso,
meses, calendario y día. Antes un fallo transitorio (por ejemplo, leer el
permiso) dejaba la pantalla atascada hasta reiniciar. `userMessageFor` es el
único lugar que decide qué texto ve el usuario ante un error.

**D44. Drift reabre una base cerrada**, así que "base cerrada" no sirve para
simular fallos de almacenamiento en tests; se simula eliminando las tablas
(SQLite responde "no such table") y se verifica que llega un `StorageFailure`
sin filtrar el error original.

**D45. Prueba de punta a punta** (`test/app/pipeline_test.dart`): galería
simulada → servicio de sync real → Drift real en memoria → providers →
pantallas, incluyendo altas, bajas y abrir el visor. En tests de widgets Drift
necesita el event loop real: las consultas se dejan correr con
`tester.runAsync` + `pump`, y la base se cierra dentro del test (cerrarla desde
`tearDown` se cuelga bajo el reloj simulado).

## Fase 9

Se midió primero (`test/perf`, ver más abajo) con una galería sintética de
51 731 assets en 130 meses, con un mes "pesado" de 3 339 fotos. La capa de datos
ya era rápida; los problemas estaban en la interfaz y en la sincronización
incremental.

**D46. Un único resumen por día alimenta el timeline y el calendario.**
`watchDayBuckets` (un `GROUP BY` sobre el día local) devuelve fecha, cantidad y
portada de cada día (~3 000 filas para 10 años). De ahí se derivan los meses
(`monthBucketsFrom`) y las filas del timeline (`buildTimelineRows`). Reemplaza a
`watchMonthBuckets` y a `monthDaysProvider`, que cargaba **todos** los assets de
un mes para poder dibujarlo. La portada sale de la misma consulta
(`platform_asset_id` junto a `MAX(capture_date)` toma la fila más reciente del
grupo; comportamiento documentado de SQLite para una sola agregación MAX, con
test). El calendario ya no carga ningún asset para dibujar un mes.

**D47. El timeline es una lista plana y perezosa de filas** (año, mes, día),
no una columna por mes. Cada día pide sus propios assets (`dayMomentsProvider`,
`autoDispose`) solo al aparecer, y los suelta al salir. Un mes de 3 339 fotos pasó
de construir 872 miniaturas a 32. Las filas tienen id estable
(`findChildIndexCallback`) para conservar su estado cuando la sincronización
agrega días arriba.

**D48. Altura reservada mientras un día carga.** Una lista perezosa cuyos
elementos cambian de altura al cargar salta al hacer scroll hacia arriba. Se
recuerda la altura real de cada día (`dayHeightCacheProvider`) y, la primera vez,
se reserva una estimada según su cantidad. Limitación: la primera vez que se
baja por un día la estimación puede no coincidir con la altura real (depende de
cuántos momentos tenga).

**D49. `throttleLatest` (300 ms) sobre el resumen por día.** Durante la primera
sincronización la base emite una vez por página escrita; sin limitar, la lista se
reconstruiría cientos de veces con datos que quedan viejos al instante. La
primera emisión sale al instante y no deja ningún `Timer` vivo si no hay ráfaga.
Nota: la consulta SQL sí se re-ejecuta en cada escritura (corre en el isolate de
la base); lo que se limita es el trabajo de la interfaz.

**D50. El sync consulta el índice por página, no entero.** `modifiedDates()`
cargaba el mapa completo de 51 731 assets en *cada* reanudación (349 ms aquí;
segundos en un teléfono) solo para mirar una o dos páginas. Ahora
`modifiedDatesOf(ids)` consulta únicamente los ids de la página (por lotes de
500, por el límite de variables de SQLite). Sincronización incremental sin
cambios: **468 ms → 6–8 ms**. Las bajas se siguen detectando al final de un
escaneo completo con `knownPlatformIds`.

**D51. Cola de miniaturas** (`ThumbnailQueue`): máximo 4 cargas simultáneas, las
más recientes primero (LIFO: lo que acaba de aparecer es lo que se mira) y se
descarta, sin llegar a la plataforma, lo que ya salió de pantalla. Cada celda
declara su interés al montarse y lo retira al desmontarse
(`ThumbnailPicture`). El visor no usa la cola: necesita su imagen de inmediato.

**D52. Bug corregido: las cargas fallidas se quedaban cacheadas.** El
`ImageCache` de Flutter conserva también una carga que falló; `NetworkImage` la
desaloja a mano y `ThumbnailImage` no lo hacía, así que un fallo transitorio
dejaba el icono de relleno hasta reiniciar la app. Ahora se desaloja siempre que
falla (incluidas las canceladas por la cola), y al volver a la celda se reintenta.

**D53. Benchmarks aparte de la suite normal.** `test/perf` (etiqueta `perf`)
no corre con `flutter test` a secas porque es lento y depende de la máquina:

```bash
flutter test --run-skipped --tags perf test/perf
```

Miden con `flutter_tester` en un equipo de escritorio, sin GPU ni la velocidad de
un teléfono: sirven para comparar antes y después, no como valores absolutos. Los
límites que afirman solo atrapan regresiones catastróficas.

| Medición (51 731 assets) | Antes | Después |
| --- | --- | --- |
| Miniaturas construidas, mes de 3 339 fotos | 872 | 32 |
| Primer frame del mes pesado (con la app ya arrancada) | ~1 540 ms | ~250 ms |
| Sincronización incremental sin cambios | 468 ms | 6–8 ms |
| Peor paso al recorrer el timeline | 377 ms | 115–144 ms |
| p95 al recorrer el timeline | 371 ms | ~97 ms |
| Sincronización completa inicial | ~0,8 s | ~0,9 s |
| Re-sincronización completa forzada | ~1,1 s | ~1,3 s |

El costo medio por paso de scroll subió (de 15 ms a ~65 ms) porque ahora el trabajo
se reparte en cada paso en vez de concentrarse en un tirón enorme al entrar a un
mes grande; el peor caso, que es lo que se percibe como tirón, bajó a un tercio.
La re-sincronización completa es algo más lenta por las consultas por página, a
cambio de no cargar el índice entero; ocurre una vez por semana.

### Lo que no se hizo (y por qué)

* **No se cambió el tamaño del `ImageCache`.** El valor por defecto (100 MB, unas
  280 miniaturas de 300 px decodificadas) cubre varias pantallas; subirlo es un
  riesgo de memoria en equipos modestos que conviene decidir con datos de
  dispositivo real.
* **Cada miniatura hace dos llamadas a la plataforma** (`AssetEntity.fromId` y
  luego la miniatura). `photo_manager` no expone la segunda sin la primera en su
  API pública; la cola limita el efecto.
* **`undatedDaysProvider` carga todos los assets sin fecha** para mostrar 8.
  Aceptable mientras sean pocos; si una galería tiene miles sin fecha, conviene
  una consulta con límite.
* **Medir en un teléfono real.** Todo lo anterior es relativo; el criterio de
  éxito de esta fase se confirma con el perfil de rendimiento de Flutter
  (DevTools) en dispositivo con la galería real.
