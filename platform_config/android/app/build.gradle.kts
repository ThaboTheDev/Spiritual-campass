plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tshk.tshk_compass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tshk.tshk_compass"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 7.0 (Nougat). Explicit rather than flutter.minSdkVersion so
        // a Flutter upgrade cannot silently drop the 1–2 GB phones we target.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Supplied by the Flutter Gradle Plugin from pubspec.yaml's `version:`.
        // The legacy `flutterVersionCode` / `flutterVersionName` project
        // properties no longer exist (Flutter 3.24 and later).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Smaller APK for low-storage phones: R8 code shrinking plus
            // resource shrinking. Keep rules live in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ABIs are NOT filtered here: an ndk abiFilters block conflicts with
            // Flutter's --split-per-abi (which sets splits.abi). Pick ABIs on the CLI:
            //   flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
            //   flutter build appbundle --release
        }
        debug {
            isMinifyEnabled = false
        }
    }

    // Fonts and JSON are already compressed; skip the dex/resource overhead of
    // multiple densities we do not ship.
    packaging {
        resources.excludes += setOf("META-INF/*.kotlin_module", "kotlin/**")
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

dependencies {
    testImplementation("junit:junit:4.13.2")
}
