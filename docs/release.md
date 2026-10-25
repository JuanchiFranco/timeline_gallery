# Publicar la app

Guía para llevar *Galería de eventos* a Google Play y a la App Store. Lo que
depende de decisiones o cuentas tuyas está marcado como **PENDIENTE**.

## 0. Estado

| | Android | iOS |
| --- | --- | --- |
| Nombre visible | Galería de eventos | Galería de eventos |
| Versión | `1.0.0` (código `1`) | `1.0.0` (build `1`) |
| Icono | generado (ver §7) | generado (ver §7) |
| Identificador | `com.novadigitalsolutions.timeline_gallery` | `com.novadigitalsolutions.timelineGallery` |
| Firma | lista para configurar (§2) | **PENDIENTE** (cuenta Apple) |
| Política de privacidad | [`privacy-policy.md`](privacy-policy.md) (hay que alojarla) | ídem |

## 1. Decisiones que solo puedes tomar tú

### 1.1 Identificador de la app (decidido)

* **Android:** `com.novadigitalsolutions.timeline_gallery`. Debe coincidir en
  `namespace` y `applicationId` de `android/app/build.gradle.kts` y en el paquete
  (y la carpeta) de `android/app/src/main/kotlin/.../MainActivity.kt`.
* **iOS:** `com.novadigitalsolutions.timelineGallery`. Apple **no admite guiones
  bajos** en los identificadores de paquete (App Store Connect los rechaza), por
  eso difiere del de Android; es la misma convención que usa Flutter al generar
  el proyecto. Está en `PRODUCT_BUNDLE_IDENTIFIER` (Debug, Release y Profile, y
  `...RunnerTests`).

**No se puede cambiar una vez publicada la app.** Si ya tenías instalada una
build de desarrollo con el identificador anterior (`com.example.*`), el sistema la
trata como otra app: desinstálala; el índice se reconstruye solo al abrir la nueva.

### 1.2 Contacto de la política de privacidad (**PENDIENTE**)

Rellena el correo en [`privacy-policy.md`](privacy-policy.md) y publícala en una
URL pública (por ejemplo GitHub Pages). Google Play la exige en la ficha.

## 2. Firma de Android

El build de release **solo** se firma de verdad si existe `android/key.properties`
(que no se versiona). Sin él, `flutter build apk --release` cae a la clave de
debug con fines de prueba local, y `flutter build appbundle` se niega a
construir, porque un `.aab` así no se puede subir.

1. Crea el keystore **fuera del repositorio** (el JDK de Android Studio trae
   `keytool`):

   ```bash
   keytool -genkey -v -keystore "C:/Users/TU_USUARIO/claves/upload-keystore.jks" \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Copia `android/key.properties.example` a `android/key.properties` y rellénalo.
3. **Haz una copia de seguridad del `.jks` y de sus contraseñas** en un gestor de
   contraseñas. Con *Play App Signing* (recomendado, es lo predeterminado) Google
   guarda la clave real de firma y esta es solo la "clave de subida", que se puede
   restablecer; sin él, perderla significa no poder actualizar nunca la app.
4. Nunca pegues el contenido de `key.properties` en un chat, un issue o un commit.

## 3. Construir

```bash
# Verificación previa (lo mismo que corre la integración continua)
dart format --set-exit-if-changed lib test
flutter analyze
flutter test

# Android: bundle para Google Play
flutter build appbundle --release
#   -> build/app/outputs/bundle/release/app-release.aab

# Android: APK para instalar directamente (pruebas, otras tiendas)
flutter build apk --release --split-per-abi
#   -> build/app/outputs/flutter-apk/app-<abi>-release.apk
```

El release activa R8 (recorte y ofuscación de código) y el recorte de recursos.
Las reglas propias están en `android/app/proguard-rules.pro`. **R8 es la causa
más típica de fallos que solo aparecen en release**: después de construir, prueba
la app firmada en un dispositivo real (§5), no solo la de debug.

### 3.1 Comprobar que la app no puede usar Internet

La política de privacidad promete que la app no se conecta a Internet. En
Android eso es verificable: el manifiesto de release no debe declarar el permiso
`INTERNET` (solo las variantes debug/profile lo llevan, para la depuración).

```bash
# aapt viene en las build-tools del Android SDK
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
```

Con las dependencias actuales (verificado en la build 1.0.0), la lista es:

| Permiso | Para qué |
| --- | --- |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | Leer la galería (Android 13+) |
| `READ_MEDIA_VISUAL_USER_SELECTED` | Acceso parcial elegido por el usuario (Android 14+) |
| `READ_EXTERNAL_STORAGE` (hasta Android 12) | Leer la galería en versiones anteriores |
| `WAKE_LOCK` | El reproductor de video evita que la pantalla se apague mientras reproduce |
| `ACCESS_NETWORK_STATE` | El reproductor de video consulta el tipo de red; **no da acceso a Internet** |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Interno de AndroidX; no es un permiso de datos |

**No debe aparecer `INTERNET`.** Si aparece, algún plugin nuevo lo añadió: hay que
revisarlo antes de publicar, porque contradice lo que le dices al usuario. Si
aparece algún permiso nuevo, actualiza esta tabla, la política de privacidad y la
declaración de Play Console.

## 4. Versionado

`version: MAJOR.MINOR.PATCH+BUILD` en `pubspec.yaml`:

* La parte antes del `+` es la versión que ve el usuario (`versionName` en
  Android, `CFBundleShortVersionString` en iOS).
* El número tras el `+` es el código de compilación (`versionCode` / `CFBundleVersion`).
  **Debe subir en cada archivo que subas a una tienda**, aunque la versión visible
  no cambie.
* Anota los cambios en [`CHANGELOG.md`](../CHANGELOG.md).

Si cambias las reglas con que se interpreta la galería (fechas, rotación…), sube
también `DefaultGallerySyncService.mappingVersion`: así la próxima sincronización
re-escanea todo y corrige lo ya indexado (ver `docs/decisions.md`, D41).

## 5. Pruebas manuales antes de publicar

Los tests automáticos no ejecutan la plataforma real. Antes de cada versión, en
un dispositivo real y con la **build de release firmada**:

**Permisos**
- [ ] Primera apertura: se muestra la explicación y "Conceder acceso" abre el diálogo del sistema.
- [ ] Denegar → aparece "Abrir ajustes"; concederlo allí y volver a la app actualiza la pantalla sola.
- [ ] Acceso limitado (Android 14+/iOS 14+): se ve el aviso y "Ajustar" permite elegir más.
- [ ] Revocar el permiso con la app en segundo plano y volver: no se cierra.

**Sincronización**
- [ ] Primera sincronización con una galería grande: muestra progreso y el timeline se va llenando.
- [ ] Cerrar la app a mitad de la primera sincronización y reabrirla: retoma, no empieza de cero.
- [ ] Sacar una foto con la app abierta, volver a la app: aparece arriba sin reiniciar.
- [ ] Borrar una foto desde otra app y volver: desaparece del timeline.
- [ ] Ajustes → "Volver a escanear la galería" funciona y termina.

**Timeline y calendario**
- [ ] Scroll rápido de arriba abajo con muchas fotos: fluido, sin pantallas en blanco prolongadas.
- [ ] El mes con más fotos se abre sin tirones.
- [ ] Fotos sin fecha (importadas, capturas antiguas): aparecen en "Sin fecha" y no rompen el calendario.
- [ ] Calendario: cambiar de mes, "Ir a hoy", abrir un día con fotos.

**Visor**
- [ ] Foto: zoom con pellizco y doble toque; con zoom, arrastrar mueve la imagen; sin zoom, desliza a la siguiente.
- [ ] Foto HEIC (iPhone) o muy grande: se ve bien.
- [ ] Video: reproducir, pausar, mover la barra, salir a mitad (el sonido se corta).
- [ ] La barra de controles del video queda abajo, no en medio.
- [ ] Rotación del dispositivo (si se permite) y modo oscuro.

**Privacidad**
- [ ] Con el modo avión activado todo funciona igual.
- [ ] `aapt dump permissions` no muestra `INTERNET` (§3.1).
- [ ] Ajustes → Privacidad: el texto coincide con lo que hace la app.

**Instalación**
- [ ] Instalar encima de la versión anterior conserva el índice y no pide permisos otra vez.
- [ ] Desinstalar y reinstalar: empieza limpia (sin copia de seguridad en la nube, a propósito).

## 6. Google Play

### 6.1 Declaración de permisos de fotos y videos (importante)

Google Play restringe `READ_MEDIA_IMAGES` y `READ_MEDIA_VIDEO` a apps cuya
**funcionalidad principal** necesita acceso amplio a la galería; el resto debe
usar el selector de fotos del sistema. Esta app es un visor de galería, que es el
caso que la política contempla, pero hay que **rellenar el formulario de
declaración** en Play Console (Contenido de la app → Permisos de fotos y videos)
explicando que la función principal es organizar toda la galería en una línea de
tiempo y un calendario, y que eso no se puede lograr con el selector.

### 6.2 Seguridad de los datos (Data safety)

* ¿Recopila o comparte datos del usuario? **No.**
* Los archivos se leen en el dispositivo y no se envían; el índice de metadatos
  nunca sale de él; no hay cuentas, analíticas, publicidad ni SDK de terceros.
* Cifrado en tránsito / solicitud de eliminación: no aplican (no hay datos fuera
  del dispositivo).

### 6.3 Ficha de la tienda (propuesta)

* **Nombre:** Galería de eventos
* **Descripción breve (≤ 80):** Tus fotos y videos como línea de tiempo y calendario. 100 % local y privado.
* **Descripción completa:**

  > Tu vida organizada como una línea de tiempo.
  >
  > Galería de eventos lee las fotos y videos que ya tienes en el dispositivo y
  > los presenta por año, mes, día y momento, para que encuentres un recuerdo por
  > cuándo ocurrió y no por cuánto hay que desplazarse.
  >
  > • Línea de tiempo agrupada en momentos (una salida, una comida, una fiesta).
  > • Calendario mensual: ve de un vistazo qué días tienen recuerdos.
  > • Visor con zoom y reproducción de video.
  > • Funciona con miles de fotos.
  >
  > Privacidad ante todo: tus archivos nunca salen del dispositivo. No hay
  > cuentas, ni servidores, ni analíticas, ni publicidad, y la app ni siquiera
  > pide permiso de Internet.

* **Capturas** (mínimo 2, recomendadas 4–8): timeline, calendario, visor, ajustes.
  Hazlas con fotos que puedas publicar.
* **Clasificación de contenido:** cuestionario de Play Console; sin contenido
  generado por usuarios ni compras.
* **Política de privacidad:** la URL de §1.2.

### 6.4 Pista de pruebas

Sube primero a **Pruebas internas** (hasta 100 testers, sin revisión larga) y
valida §5 con la build que descargues de Play, no solo con la local.

## 7. Iconos

Los PNG de `assets/icon/` son el origen; los recursos de cada plataforma se
generan con:

```bash
dart run flutter_launcher_icons
```

> **Aviso:** `flutter_launcher_icons` 0.14.x reescribe mal el ajuste
> `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` de
> `ios/Runner.xcodeproj/project.pbxproj` (lo deja en `AppIcon` cuando debe ser
> `YES`). Después de ejecutarlo, revisa `git diff` y revierte ese archivo:
> `git checkout ios/Runner.xcodeproj/project.pbxproj`.

El icono actual (un cuadro de foto con sol y montañas sobre el terracota de la
marca) es una **propuesta funcional**; si tienes uno diseñado, sustituye
`assets/icon/icon.png` (1024×1024, opaco) e `icon_foreground.png` (1024×1024,
transparente, el glifo dentro del 66 % central) y vuelve a generar.

## 8. iOS (necesita un Mac)

No se puede compilar ni firmar iOS desde Windows. En un Mac con Xcode:

1. Abre `ios/Runner.xcworkspace`, elige tu *Team* y el identificador de §1.1.
2. `flutter build ipa --release`, o *Product → Archive* en Xcode, y súbelo con
   *Transporter* / *Distribute App*.
3. En App Store Connect:
   * **App Privacy:** "Data Not Collected".
   * **Texto de uso de fotos** (`NSPhotoLibraryUsageDescription`): ya está en
     `Info.plist` y se muestra en el diálogo del sistema; es el que revisa Apple.
4. Añade un `PrivacyInfo.xcprivacy` al target Runner desde Xcode si tu versión de
   Flutter aún no lo incluye (declara que no hay seguimiento ni recopilación).
   Los plugins que usa la app traen el suyo.

## 9. Integración continua

`.github/workflows/ci.yml` ejecuta formato, análisis y tests en cada push y pull
request, y compila el APK de release. No firma ni publica nada: la firma y la
subida a las tiendas se hacen a mano, a propósito.

> Al subir un archivo de `.github/workflows/` con un token de GitHub, este
> necesita el permiso `workflow`; si el push es rechazado por eso, súbelo desde la
> interfaz web o amplía el token.

## 10. Problemas conocidos del entorno de desarrollo (Windows)

* **`Cannot snapshot ...: not a regular file`** al compilar Android: los archivos
  del SDK de Flutter están marcados como marcadores de posición de un servicio de
  sincronización en la nube (etiqueta de reparse `0x9000201A`), que Gradle 9 no
  sabe leer. Instala o mueve el SDK a una carpeta **que no sincronice la nube**
  (por ejemplo `C:\src\flutter`) y apunta `flutter.sdk` allí.
* **`Could not write file ... .spirv`** al compilar: rutas de más de 260
  caracteres. Mantén el proyecto en una ruta corta.
