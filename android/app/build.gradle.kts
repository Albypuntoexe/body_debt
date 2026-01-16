plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.body_debt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // CORREZIONE 1: Sintassi Kotlin DSL (uso di = e is...)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.body_debt"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// CORREZIONE 2: Il blocco dependencies deve stare FUORI da android {}
dependencies {
    // CORREZIONE 3: Sintassi corretta per aggiungere la dipendenza in Kotlin
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}