import java.util.Properties

plugins {
    id("com.android.application")
    // Firebase (FCM) — phải đứng trước Flutter plugin.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()

if (hasReleaseSigning) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

android {
    namespace = "com.familycare.family_care"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Unit test Kotlin nằm ở src/test/kotlin. Không khai dòng này thì AGP chỉ
    // nhìn src/test/java, và toàn bộ test trong repo bị BỎ QUA IM LẶNG:
    // `./gradlew :app:testDebugUnitTest` vẫn BUILD SUCCESSFUL nhưng báo cáo
    // ghi "0 tests, 0 failures" (phát hiện 2026-08-17 — cả 3 file test
    // FallDetectorTest / ShakeDetectorTest / EmergencySosMatcherTest chưa từng
    // chạy lần nào kể từ khi được viết).
    sourceSets.getByName("test") {
        java.srcDir("src/test/kotlin")
    }

    compileOptions {
        // flutter_local_notifications yêu cầu core library desugaring
        // (dùng java.time trên minSdk < 26). Thiếu dòng này build sẽ fail ở
        // task :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ⚠️ TẠM ĐỔI 20/07: phải khớp package_name trong google-services.json
        // BE cấp (com.company.familycare) thì Firebase mới build được.
        // Package "đúng" của app là com.familycare.family_care (= namespace).
        // Khi BE thêm com.familycare.family_care vào Firebase project
        // familycare-387d1 và cấp file mới → đổi lại dòng này về cũ.
        // ⚠️ ĐỔI DÒNG NÀY THÌ PHẢI SỬA CẢ `android:targetPackage` trong
        // src/main/res/xml/shortcuts.xml (lối tắt SOS ngoài màn hình chính).
        // Không khớp thì lối tắt im lặng không mở được app: không lỗi build,
        // không crash, chỉ là bấm vào không có gì xảy ra.
        applicationId = "com.company.familycare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Never publish a release signed with the debug key. CI creates
            // android/key.properties from GitHub Secrets before this build.
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    null
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
    // SosEmergencyFlowService: lấy GPS + cache token mã hoá khi phát hiện té
    // ngã, độc lập Flutter engine (xem android/.../SosEmergencyFlowService.kt).
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    // Cầu nối với Garmin watch app (GarminBridgeService) — nhận message
    // PAIR_CONFIRMED/FALL_DETECTED qua Garmin Connect Mobile. Phân phối trên
    // Maven Central (không cần .aar thủ công), xem
    // https://developer.garmin.com/connect-iq/core-topics/mobile-sdk-for-android/
    implementation("com.garmin.connectiq:ciq-companion-app-sdk:2.4.0@aar")
}

flutter {
    source = "../.."
}
