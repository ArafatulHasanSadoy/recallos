import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key, read from `android/key.properties` — which is gitignored,
// because it holds the passwords in the clear.
//
// A fresh clone has no `key.properties`, so this falls back to the debug key
// rather than failing the build: `flutter run --release` has to keep working
// for anyone who checks the project out, and for the release runs this project
// leans on to catch R8 bugs. The fallback is *only* safe because Play refuses a
// debug certificate outright — a debug-signed bundle cannot be uploaded by
// accident, it is rejected at the door.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.recallos.recallos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.recallos.recallos"
        // Pinned rather than inherited. ML Kit GenAI (Gemini Nano) requires
        // API 26; ML Kit text recognition floors at 21. Android 8.0 shipped in
        // 2017, so this still reaches effectively every phone in use.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                // Absolute path in `key.properties`. A relative one would
                // resolve against `android/app/`, which is not where anybody
                // keeps a keystore.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
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
