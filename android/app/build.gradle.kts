plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pir_motion_app"
    compileSdk = 34
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.pir_motion_app"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
    debug {
        // ⚠️ Do not shrink resources in debug
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.24")

    // Required for Java 8+ APIs (desugaring)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

apply(plugin = "com.google.gms.google-services")

