plugins {
    id("com.android.application")
    // Firebase (FCM) — phải đứng trước Flutter plugin.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.familycare.family_care"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

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
        applicationId = "com.company.familycare"
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
}

flutter {
    source = "../.."
}
