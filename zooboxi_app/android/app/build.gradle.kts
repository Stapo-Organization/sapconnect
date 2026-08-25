plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zooboxi.zooboxi_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Store identity: com.zooboxi.store (locked before first upload; the Kotlin
        // namespace below stays as generated, which Android permits).
        // application id cannot be changed once published.
        applicationId = "com.zooboxi.store"
        // 26 is MyFatoorah's floor (its Android SDK declares minSdk 26); it also
        // clears Flutter's own 24 and mobile_scanner's 23. Raising it is not
        // optional — a lower value fails the manifest merge outright.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The app ships Arabic and English only; without this, Play would
        // advertise every locale the bundled libraries happen to carry.
        resourceConfigurations += listOf("ar", "en")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
