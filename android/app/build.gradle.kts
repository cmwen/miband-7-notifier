import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// =============================================================================
// RELEASE SIGNING CONFIGURATION
// =============================================================================
// To sign release builds, create a file `android/key.properties` with:
//
//   storePassword=your_keystore_password
//   keyPassword=your_key_password
//   keyAlias=your_key_alias
//   storeFile=path/to/your-keystore.jks
//
// For CI/CD, these are set via GitHub Secrets:
//   ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD,
//   ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
//
// AI PROMPT: To set up signing, ask AI to help you:
//   1. Generate a keystore: keytool -genkey -v -keystore release.jks ...
//   2. Create key.properties file
//   3. Add secrets to GitHub repository settings
// =============================================================================
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.cmwen.miband7notifier"
    compileSdk = flutter.compileSdkVersion
    buildToolsVersion = "36.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cmwen.miband7notifier"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Build optimization settings
    buildFeatures {
        buildConfig = false
        aidl = false
        renderScript = false
        shaders = false
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Faster debug builds
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // Enable R8 code shrinking and resource shrinking for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Use release signing config if available, otherwise fall back to debug
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        jniLibs {
            keepDebugSymbols += "**/*.so"
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Force JVM 17 for all dependency projects
afterEvaluate {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class).all {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    // Flutter may register empty CMake tasks only to trigger NDK downloads.
    // This app has no native sources, so skipping them avoids WSL/Windows SDK mismatches.
    tasks.configureEach {
        if (
            name.startsWith("configureCMake") ||
            name.startsWith("buildCMake") ||
            name.startsWith("externalNativeBuild") ||
            name.startsWith("generateJsonModel")
        ) {
            enabled = false
        }
    }
}
