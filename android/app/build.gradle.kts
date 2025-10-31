plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.lexiflow.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Java 17 desteği + desugaring aktif
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // ✅ Kotlin derleyicisi de Java 17’ye göre ayarlandı
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

   defaultConfig {
    applicationId = "com.lexiflow.app"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    
    // AdMob placeholder substitution
    manifestPlaceholders["ADMOB_APP_ID"] = project.findProperty("ADMOB_APP_ID") ?: "ca-app-pub-3940256099942544~3347511713"
}


    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
      coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
          implementation("androidx.appcompat:appcompat:1.4.0")


}
