import java.util.Properties

// Machine-specific overrides. Gitignored, so CI and other developers are
// unaffected by anything set here.
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aryan.proxymate"
    compileSdk = flutter.compileSdkVersion

    // Normally just flutter.ndkVersion. One dev machine has a corrupt install
    // of that version, so it can be overridden per-machine by adding
    //   ndk.version=27.1.12297006
    // to android/local.properties, which is gitignored. CI and every other
    // machine get the default and download it normally.
    ndkVersion = localProps.getProperty("ndk.version") ?: flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time on minSdk < 26, so it
        // requires the desugared JDK library.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Deliberately different from the `svnit` branch's "com.aryan.proxymate".
        // Android keys installed apps by applicationId, so this is the one and
        // only change needed to run both builds side by side on one phone.
        // The label and icon are intentionally left alone.
        applicationId = "com.aryan.proxymate.general"
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
