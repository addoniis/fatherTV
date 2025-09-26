plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.news_stream_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

compileOptions {
    // 保持與 Flutter 預設的 11 一致
    // 13:53 modify to 17 adonis
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17

    // **重要: 針對 youtube_player_flutter 啟用 Java 8 支援**
    // 註：在 Kotlin DSL 中，這通常是 implicit 的，但為確保相容性，我們通常檢查 minSdk 或使用這組配置。
    // 在你的情況下，因為 Flutter 預設是 11，套件通常會需要更低版本的明確支援。
    // 由於你使用的是 JavaVersion.VERSION_11，這個設定已經包含了 Java 8 的功能。
    // 但如果之後遇到錯誤，請嘗試確保使用的 API 是 Java 8 級別的。
    // 實際上，如果你使用版本 11，它已能處理大部分情況，可以先嘗試不修改，
    // 若出錯，再嘗試切換到 Java 8 語法。
}

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.news_stream_app"
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

        // 【修正 1】：將 minifyEnabled 移入區塊內
        // 【修正 2】：將 minifyEnabled 替換為 isMinifyEnabled (Kotlin DSL 正確名稱)
        isMinifyEnabled = false // <--- 修正後的關鍵行

        // 【新增關鍵行】：關閉資源縮減
        isShrinkResources = false // <--- 修正這個錯誤

        // 確保 ProGuard 文件設定為空，以防止誤讀 (此行保持在區塊內)
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
    // 如果您需要確保 debug 也沒有混淆 (通常不用，但安全起見可以檢查)
    // debug {
    //     isMinifyEnabled = false // 預設就是 false
    // }
  }
}


flutter {
    source = "../.."
}
