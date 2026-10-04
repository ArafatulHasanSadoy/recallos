import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key, read from `android/key.properties` — which is gitignored,
// because it holds the passwords in the clear.
//
// Without it a release build signs with the debug key — but only when asked
// to, with RECALLOS_ALLOW_DEBUG_SIGNING=true. It used to fall back silently,
// which was "safe" only because Play rejects a debug certificate at the door:
// a bundle that looked finished, built from a laptop where the key file had
// gone missing, failed only at upload time. Now it fails at build time and
// says why. Local release runs (the R8 checks this project leans on) and CI,
// neither of which is ever uploaded, set the variable.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null
val allowDebugSigning = System.getenv("RECALLOS_ALLOW_DEBUG_SIGNING") == "true"
val refuseReleaseSigning = !hasUploadKey && !allowDebugSigning
// A build marked never-to-be-uploaded keeps the debug key even when the upload
// key is present. The phone's install is debug-signed, and Android refuses a
// differently signed build over it except by uninstalling — which deletes the
// wallet. So a device check never switches keys by accident; the switch to the
// Play-signed app is done once, deliberately, behind a backup.
val signWithUploadKey = hasUploadKey && !allowDebugSigning

android {
    namespace = "com.recallos.recallos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time, which older
        // Android versions lack; desugaring supplies it down to minSdk 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.recallos.recallos"
        // Pinned rather than inherited. It was 26 for ML Kit GenAI (Gemini
        // Nano); that package was removed because nothing used it, and ML Kit
        // text recognition alone floors at 21. It stays 26 because every
        // device check so far ran on 26+, and Android 8.0 shipped in 2017 —
        // this still reaches effectively every phone in use.
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
            signingConfig = if (signWithUploadKey) {
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

// Checked when the release artifact is actually signed, not when the build is
// configured — so `flutter run` in debug, which configures the release build
// type too, is never affected.
tasks.matching { it.name == "packageRelease" || it.name == "signReleaseBundle" }
    .configureEach {
        doFirst {
            if (refuseReleaseSigning) {
                throw GradleException(
                    "No upload key: android/key.properties is missing, so this " +
                        "release build would be signed with the Android debug key, " +
                        "which Google Play rejects. Create the upload key " +
                        "(docs/RELEASE.md §1) — or, for a local test or CI build " +
                        "that will never be uploaded, set " +
                        "RECALLOS_ALLOW_DEBUG_SIGNING=true.",
                )
            }
        }
    }

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
