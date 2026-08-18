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

// Signing details, absent on machines that only ever sideload.
val keystoreFile = rootProject.file("key.properties")
val keystoreProperties: Properties? = if (keystoreFile.exists()) {
    Properties().apply { keystoreFile.inputStream().use { load(it) } }
} else {
    null
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
        // Permanent once published: Play identifies an app by this string, and
        // changing it would create a separate listing with its own reviews and
        // installs. The SVNIT fork uses com.aryan.proxymate.svnit so the two
        // still install side by side.
        applicationId = "com.aryan.proxymate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Real signing details live in android/key.properties, which is
        // gitignored: a keystore committed to a public repo is a keystore
        // anyone can publish updates with.
        if (keystoreProperties != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")
                    ?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when key.properties is absent, so a
            // fresh clone can still run `flutter build apk --release` for
            // sideloading. Play rejects debug-signed uploads, so a real
            // upload build simply requires the file to exist.
            signingConfig = if (keystoreProperties != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
