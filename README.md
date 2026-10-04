# Galería de eventos

Tu vida organizada como una línea de tiempo: la app lee las fotos y videos de
la galería del dispositivo y los presenta como un calendario/timeline visual
de recuerdos (año → mes → día → momento).

**100% local**: los archivos nunca salen del dispositivo, no hay cuentas, ni
servidores, ni analytics. La galería del dispositivo es la fuente de verdad;
la app solo guarda un índice de metadatos.

> Estado: **Fase 5 (Timeline)** — permiso de galería, sincronización
> completa/incremental hacia el índice local y línea de tiempo agrupada por
> año → mes → día → momento con miniaturas. El calendario llega en la Fase 6.
> El diseño completo está en el documento *Arquitectura: Galería como
> Timeline de Recuerdos*.

## Requisitos

- Flutter estable con Dart **≥ 3.10** (requerido por `drift` 2.35).
- Android Studio / Xcode según la plataforma de destino.

## Primera ejecución

El repositorio contiene `lib/`, `test/` y la configuración; las carpetas
nativas (`android/`, `ios/`) las genera Flutter una sola vez:

```bash
flutter create --platforms=android,ios --project-name galeria_eventos .
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift
flutter run
```

`flutter create .` no sobrescribe los archivos existentes. Después puedes
borrar el `test/widget_test.dart` que genera por defecto.

### Permisos nativos (después de `flutter create`)

`photo_manager` los necesita declarados en las carpetas generadas (ya están
incluidos en este repo; se listan por si regeneras `android/` o `ios/`):

- **Android** (`android/app/src/main/AndroidManifest.xml`), dentro de
  `<manifest>`:

  ```xml
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
  <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
  <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED"/>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
      android:maxSdkVersion="32"/>
  ```

  Y `minSdkVersion` ≥ 21 en `android/app/build.gradle`.
- **iOS** (`ios/Runner/Info.plist`):

  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Usamos tu galería para organizar tus fotos y videos en una línea de tiempo. Todo se queda en tu dispositivo.</string>
  ```

Verificación:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Configuración

Sin configuración la app corre con valores por defecto. Para ajustarlos:

```bash
cp .env.example .env
flutter run --dart-define-from-file=.env
```

No hay secretos; ver `.env.example`.

## Estructura

```text
lib/
├── app/            # app, router (go_router), theme
├── core/           # error, logging, config, database (Drift), di, widgets
└── features/
    ├── gallery/    # índice local: domain / data / presentation
    ├── timeline/
    ├── calendar/
    └── settings/
```

Flujo de datos (la UI nunca toca la plataforma):

```text
Galería del dispositivo → Platform Adapter → Gallery Repository
  → Sync Service → Base de datos local → Dominio → Riverpod → UI
```

Decisiones técnicas: [`docs/decisions.md`](docs/decisions.md).

## Roadmap

| Fase | Contenido |
| --- | --- |
| 2 | Foundation |
| 3 | Permisos + lectura de galería (`photo_manager`) |
| 4 | Sincronización incremental |
| 5 | Timeline y agrupación por momentos (esta) |
| 6 | Calendario |
| 7 | Visor de fotos y videos |
| 8–10 | Tests, performance, release |
