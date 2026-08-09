import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// 发布签名配置（优雅降级）
// 若存在 `android/key.properties`（本地生成、不入库），则使用正式 release 签名；
// 否则（开发 / CI 环境）回落 debug 签名，保证构建不中断。
//
// 生成正式密钥：
//   mkdir -p ~/keystores && keytool -genkey -v \
//     -keystore ~/keystores/mephisto.jks \
//     -keyalg RSA -keysize 2048 -validity 10000 -alias mephisto
//
// 然后在 `android/key.properties` 写入：
//   storePassword=你的库密码
//   keyPassword=你的Key密码
//   keyAlias=mephisto
//   storeFile=/home/你的用户/keystores/mephisto.jks  （绝对路径）
// ============================================================
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "yuelinghuashu.mephisto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "yuelinghuashu.mephisto"
        // minSdk 23（Android 6.0）：flutter_secure_storage 9.x 要求 API ≥ 23；
        // 2026 年 Android 5.0（API 21）已完全停产，放弃兼容无实际影响。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 正式签名：仅当 key.properties 存在时定义
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 有正式密钥 → 用 release 签名；否则回落 debug（GitHub 分发 / 开发可用）
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
