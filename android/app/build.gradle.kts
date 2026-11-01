import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mapsProperties = Properties()
val mapsPropertiesFile = rootProject.file("maps.properties")
if (mapsPropertiesFile.exists()) {
    mapsPropertiesFile.inputStream().use(mapsProperties::load)
}
val googleMapsAndroidApiKey =
    System.getenv("GOOGLE_MAPS_ANDROID_API_KEY")
        ?: mapsProperties.getProperty("GOOGLE_MAPS_ANDROID_API_KEY")
        ?: ""

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use(keyProperties::load)
}
fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)
        ?: keyProperties.getProperty(propertyName)

val androidKeystorePath = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")
val androidKeystorePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val androidKeyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
val androidKeyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
val hasReleaseSigning = listOf(
    androidKeystorePath,
    androidKeystorePassword,
    androidKeyAlias,
    androidKeyPassword,
).all { !it.isNullOrBlank() }
val signDebugWithRelease = System.getenv("ANDROID_SIGN_DEBUG_WITH_RELEASE") == "true"
val standardIntegrationTest =
    providers.gradleProperty("standardIntegrationTest").orNull == "true"

android {
    namespace = "com.raychiu.tripline"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.raychiu.tripline"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsAndroidApiKey
        // 授權回跳（App Link）的網域與路徑；要與 Dart 端 TRIPLINE_OAUTH_CALLBACK_HOST／
        // TRIPLINE_OAUTH_CALLBACK_PATH 以及後端登記的 redirect URI 一致。
        // 切換網域時：./gradlew ... -PoauthCallbackHost=<host> -PoauthCallbackPath=<path>
        manifestPlaceholders["oauthCallbackHost"] =
            (project.findProperty("oauthCallbackHost") as String?)
                ?: "mobile-callback.trip-planner-dby.pages.dev"
        manifestPlaceholders["oauthCallbackPath"] =
            (project.findProperty("oauthCallbackPath") as String?)
                ?: "/oauth/callback"
        testInstrumentationRunner =
            if (standardIntegrationTest) {
                "androidx.test.runner.AndroidJUnitRunner"
            } else {
                "pl.leancode.patrol.PatrolJUnitRunner"
            }
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    sourceSets {
        getByName("androidTest") {
            if (standardIntegrationTest) {
                java.setSrcDirs(
                    listOf("src/standardIntegrationAndroidTest/java"),
                )
            }
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(androidKeystorePath!!)
                storePassword = androidKeystorePassword
                keyAlias = androidKeyAlias
                keyPassword = androidKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            if (hasReleaseSigning && signDebugWithRelease) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.fromTarget("17")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
    // App 鎖(local_auth)的 BiometricPrompt 需要 AppCompat 主題資源。
    implementation("androidx.appcompat:appcompat:1.7.0")
    androidTestUtil("androidx.test:orchestrator:1.5.1")
    // 純轉換（DPoP 金鑰的 DER／座標）的 JVM 單元測試。
    testImplementation("junit:junit:4.13.2")
}
