plugins {
    id("com.android.application")
    // AGP 9 is explicitly in legacy Kotlin mode (android.builtInKotlin=false).
    // Apply KGP before the Flutter Gradle Plugin; otherwise Kotlin sources and
    // the kotlin.compilerOptions extension are not consistently configured.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The client has not supplied its final app identifier or signing material.
// Debug builds still work; unverified/debug-signed release builds must fail.
val orbitAndroidId = System.getenv("ORBIT_ANDROID_APPLICATION_ID")?.trim()
    ?.takeIf { it.matches(Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*){1,}$")) }
    ?: "com.example.orbit_ui"
// Platform-key injection. Separate Android-restricted and iOS-restricted keys.
val orbitGoogleMapsProperties = java.util.Properties()
val orbitGoogleMapsLocal = rootProject.file("secrets.properties")
if (orbitGoogleMapsLocal.isFile) {
    orbitGoogleMapsLocal.inputStream().use { orbitGoogleMapsProperties.load(it) }
}
val orbitGoogleMapsAndroidKey = System.getenv("ORBIT_GOOGLE_MAPS_ANDROID_API_KEY")
    ?.trim()?.takeIf { it.isNotEmpty() }
    ?: orbitGoogleMapsProperties.getProperty("ORBIT_GOOGLE_MAPS_ANDROID_API_KEY")
        ?.trim()?.takeIf { it.isNotEmpty() }
    ?: "NO_GOOGLE_MAPS_ANDROID_KEY_CONFIGURED"
val orbitStore = System.getenv("ORBIT_ANDROID_KEYSTORE_PATH")
val orbitStorePass = System.getenv("ORBIT_ANDROID_KEYSTORE_PASSWORD")
val orbitKeyAlias = System.getenv("ORBIT_ANDROID_KEY_ALIAS")
val orbitKeyPass = System.getenv("ORBIT_ANDROID_KEY_PASSWORD")
val orbitHasSigning = listOf(orbitStore, orbitStorePass, orbitKeyAlias, orbitKeyPass)
    .all { !it.isNullOrBlank() }

android {
    namespace = "com.example.orbit_ui"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = orbitAndroidId
        manifestPlaceholders["ORBIT_GOOGLE_MAPS_ANDROID_API_KEY"] = orbitGoogleMapsAndroidKey
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (orbitHasSigning) {
            create("orbitRelease") {
                storeFile = file(orbitStore!!)
                storePassword = orbitStorePass
                keyAlias = orbitKeyAlias
                keyPassword = orbitKeyPass
            }
        }
    }
    buildTypes {
        release {
            // Never sign a distributable Orbit release with debug credentials.
            signingConfig = if (orbitHasSigning) signingConfigs.getByName("orbitRelease") else null
        }
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

// The user-facing release is prohibited until the actual signed identity is
// provisioned by the client. No signing credentials belong in GitHub.
tasks.matching {
    it.name in listOf("assembleRelease", "bundleRelease", "packageRelease")
}.configureEach {
    doFirst {
        if (orbitAndroidId == "com.example.orbit_ui" || !orbitHasSigning ||
            !file(orbitStore!!).isFile) {
            throw org.gradle.api.GradleException(
                "Orbit release blocked: set verified ORBIT_ANDROID_APPLICATION_ID and " +
                "ORBIT_ANDROID_KEYSTORE_PATH/PASSWORD/KEY_ALIAS/KEY_PASSWORD."
            )
        }
    }
}
