plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "net.ezaz.tv"
    compileSdk = 34

    defaultConfig {
        applicationId = "net.ezaz.tv"
        minSdk = 26          // Android 8.0 (Oreo) — covers all current Android TV devices
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    signingConfigs {
        create("release") {
            val keystoreFile = (project.findProperty("EZAZ_KEYSTORE_FILE") as String?)
            val keystorePassword = (project.findProperty("EZAZ_KEYSTORE_PASSWORD") as String?)
            val keyAliasProp = (project.findProperty("EZAZ_KEY_ALIAS") as String?)
            val keyPasswordProp = (project.findProperty("EZAZ_KEY_PASSWORD") as String?)
            if (keystoreFile != null && keystorePassword != null && keyAliasProp != null && keyPasswordProp != null) {
                storeFile = file(keystoreFile)
                storePassword = keystorePassword
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = false
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.leanback:leanback:1.0.0")
    implementation("androidx.webkit:webkit:1.11.0")
}
