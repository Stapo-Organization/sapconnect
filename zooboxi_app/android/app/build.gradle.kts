import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Play upload key lives outside the repo: android/key.properties (git-ignored)
// names the keystore and its passwords. A machine without it still builds — the
// release then signs with the debug key, which installs on a device but Play
// refuses. See tool/PLAY.md.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

// Push on Android needs the Firebase config (android/app/google-services.json,
// git-ignored). The plugin that reads it fails the build when the file is
// missing, so it is applied only once the file is there; without it the app
// builds and runs, with push quietly off.
if (project.file("google-services.json").exists()) {
    project.apply(plugin = "com.google.gms.google-services")
    logger.lifecycle("google-services: config found, plugin applied")
} else {
    logger.lifecycle("google-services: no config, push off")
}

android {
    namespace = "com.zooboxi.zooboxi_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time; older Androids get it
        // through desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Store identity: com.zooboxi.app (locked before first upload; the Kotlin
        // namespace below stays as generated, which Android permits).
        // application id cannot be changed once published.
        applicationId = "com.zooboxi.app"
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

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")
            // R8: shrink, optimise and obfuscate the Java/Kotlin side (Play's
            // "DEX code optimization" check). Dart lives in libapp.so and is
            // untouched, so Shorebird patches are unaffected. Plugin keep rules
            // come from each plugin's consumer file; ours are in
            // proguard-rules.pro, kept resources in res/raw/keep.xml.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

// myfatoorah_flutter ships a consumer rule `-keep class * { *; }` that would
// switch R8 off for the whole app (Play then flags "DEX code optimization:
// Low"). Plugins evaluate after :app, so this drops that file before AGP
// reads it; the keeps MyFatoorah genuinely needs are in proguard-rules.pro.
rootProject.findProject(":myfatoorah_flutter")?.afterEvaluate {
    extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        ?.defaultConfig?.consumerProguardFiles?.clear()
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
