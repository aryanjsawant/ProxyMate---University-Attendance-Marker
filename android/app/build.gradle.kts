plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aryan.proxymate"
    compileSdk = flutter.compileSdkVersion

    // Pinned rather than flutter.ndkVersion (28.2.13676358): that version is a
    // failed partial install on this machine (no source.properties), so AGP
    // tries to re-download it and fails. 27.1.12297006 is complete and locally
    // present. Nothing here ships native code, so the NDK is only satisfying
    // AGP's configure-time check.
    ndkVersion = "27.1.12297006"

    compileOptions {
        // flutter_local_notifications uses java.time on minSdk < 26, so it
        // requires the desugared JDK library.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.aryan.proxymate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Version matches what flutter_local_notifications declares, and is already
    // in the local Gradle cache — important because Maven Central is
    // unreachable from this network.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
