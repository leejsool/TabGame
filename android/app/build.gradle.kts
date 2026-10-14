import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tabgame.tabgame"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tabgame.tabgame"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "tabgame"
        manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
    }

    // 개발용 빌드 (tool/build_dev.ps1): 릴리즈 앱과 나란히 설치되도록 앱 ID를 따로 쓰고,
    // 아이콘에 '개발' 띠를 붙인다. 환경변수 TABGAME_DEV=1 일 때만 적용된다.
    if (System.getenv("TABGAME_DEV") == "1") {
        defaultConfig {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appLabel"] = "tabgame 개발"
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher_dev"
        }
    }

    // Release keystore lives outside the repo (F:\MyApp\key); secrets are never committed.
    val keystoreProps = Properties()
    val keystorePropsFile = file("../../../key/keystore.properties")
    val hasReleaseKey = keystorePropsFile.exists()
    if (hasReleaseKey) {
        keystorePropsFile.inputStream().use { keystoreProps.load(it) }
    }
    val keystoreFileName = keystoreProps.getProperty("storeFile", "").substringAfterLast('/')

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file("../../../key/$keystoreFileName")
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing when the key folder is missing.
            signingConfig = if (System.getenv("TABGAME_DEV") == "1") {
                // 개발용 빌드는 릴리즈 키를 쓰지 않는다
                signingConfigs.getByName("debug")
            } else if (hasReleaseKey) {
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
