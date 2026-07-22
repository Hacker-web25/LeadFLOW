plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.leadflow_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.leadflow.ai"
        // Raised from Flutter's default (typically 21) — some of our deps
        // (google_mlkit_text_recognition, record, just_audio) require modern
        // camera/media APIs. 23 is safe: covers 99%+ of active Android devices.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ML Kit + pluto_grid + audio libs push method count past the Dalvik
        // 64K limit on release builds. Multidex is free insurance.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Debug-key signing so `flutter build apk --release` just works
            // without keystore setup. Fine for internal testing; replace with
            // a real signing config before publishing to Play Store.
            signingConfig = signingConfigs.getByName("debug")
            // Shrink + obfuscate the release APK.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Silence a warning from just_audio's dependency on org.json.
    packaging {
        resources {
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/LICENSE.md"
            excludes += "META-INF/LICENSE-notice.md"
        }
    }
}

dependencies {
    // Multidex support library — required whenever multiDexEnabled = true on
    // API < 21. We're at minSdk 23 so it's optional, but harmless and future-proof.
    implementation("androidx.multidex:multidex:2.0.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
