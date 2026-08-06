import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.test.app.testfeature.apps"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.test.app.testfeature.apps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // ADD THESE 3 LINES ↓
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    val dartEnvironmentVariables = mutableMapOf<String, String>()
    if (project.hasProperty("dart-defines")) {
        val dartDefines = project.property("dart-defines") as String
        dartDefines.split(",").forEach { entry ->
            try {
                val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
                val pair = decoded.split("=")
                if (pair.size == 2) {
                    dartEnvironmentVariables[pair[0]] = pair[1]
                }
            } catch (e: Exception) {
                // Ignore decoding errors
            }
        }
    }

    val useNextGenSdk = dartEnvironmentVariables["USE_NEXT_GEN_SDK"]?.toBoolean() ?: false

    sourceSets {
        getByName("main") {
            if (useNextGenSdk) {
                java.srcDirs("src/main/kotlin", "src/nextgengma/kotlin")
                res.srcDirs("src/nextgengma/res", "src/main/res")
            } else {
                java.srcDirs("src/main/kotlin", "src/playservices/kotlin")
                res.srcDirs("src/playservices/res", "src/main/res")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Cryptography for RSA certificate generation
    implementation("org.bouncycastle:bcprov-jdk15on:1.70")
    implementation("org.bouncycastle:bcpkix-jdk15on:1.70")
    implementation("com.facebook.android:facebook-android-sdk:18.0.3")
    // Kotlin Coroutines for asynchronous socket/pairing flows
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1")

    // Google Cast Sender SDK & MediaRouter
    implementation("androidx.mediarouter:mediarouter:1.2.5")
    implementation("com.google.android.gms:play-services-cast-framework:22.3.1")
}
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}