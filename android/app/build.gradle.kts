import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release. Las credenciales viven en android/key.properties, que NUNCA
// se versiona (ver android/key.properties.example y docs/release.md).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.novadigitalsolutions.timeline_gallery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador DEFINITIVO: no se puede cambiar una vez publicada la app.
        // Debe coincidir con `namespace` y con el paquete de MainActivity.kt.
        applicationId = "com.novadigitalsolutions.timeline_gallery"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Con keystore, firma de release. Sin él (desarrollo local) se cae a la
            // clave de debug para poder probar `flutter run --release`; el bundle
            // para la tienda se niega a construirse así (ver más abajo).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Recorta y ofusca el código y los recursos que no se usan.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Un .aab firmado con la clave de debug no se puede subir a Google Play y delata
// que falta configurar la firma: mejor fallar aquí que al subirlo.
gradle.taskGraph.whenReady {
    // Solo la tarea exacta: AGP tiene tareas internas (bundleReleaseResources...)
    // que también se ejecutan en un assembleRelease.
    val buildsStoreBundle = allTasks.any { it.name == "bundleRelease" }
    if (buildsStoreBundle && !hasReleaseKeystore) {
        throw GradleException(
            "Falta android/key.properties: no se puede firmar el bundle de release. " +
                "Ver docs/release.md (sección \"Firma\")."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
