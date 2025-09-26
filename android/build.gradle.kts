allprojects {
    repositories {
        google()
        mavenCentral()
    }
// 13:36 Adonis Add
    configurations.all {
        resolutionStrategy {
            // 這會強制 AGP 忽略這個舊版套件的錯誤
            // 由於我們沒有用到它的 InAppWebView 功能，這通常是安全的
            // 這是針對 AGP 8.x+ 的一個常見 Workaround
            force("com.android.tools.build:gradle:7.3.0")
        }
    }

}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

//13:14 Adonis mask
//subprojects {
//  project.evaluationDependsOn(":app")
//}


//13:14 Adonis Add
// android/build.gradle.kts
// 強制為特定子專案設定 namespace 的修正邏輯
//13:42 Adonis remove
/*
subprojects {
    afterEvaluate {
        if (project.name == "flutter_inappwebview") {
            try {
                // 使用 dynamic 方式存取 andriod 擴展
                val androidExtension = project.extensions.getByName("android")

                // 檢查是否是 Library 模組並嘗試設定 namespace
                if (androidExtension.javaClass.simpleName == "LibraryExtensionImpl" ||
                    androidExtension.javaClass.simpleName == "AppExtensionImpl") {

                    // 使用 property 寫法來設定 namespace
                    (androidExtension as com.android.build.gradle.BaseExtension).namespace = "com.pichillilorenzo.flutter_inappwebview"
                    println("Forced namespace on $project") // 輸出確認
                }
            } catch (ignored: Exception) {
                // 忽略錯誤，確保其他專案不受影響
            }
        }
    }
}
*/


//13:14 Adonis Add
//更新 Android Gradle Plugin (AGP) 和 Kotlin 版本
//13:33 Adonis modified

// android/build.gradle.kts (專案級別)
//重點： 我們只需確保這些插件在 classpath 中，無需指定版本號。由於你的環境已經找到 AGP 8.9.1，讓它使用這個版本即可。
plugins {
    // 移除版本號碼 '8.1.0'，讓 Gradle 使用它已經找到的版本 (8.9.1)
    id("com.android.application") apply false
    // 移除版本號碼 '1.8.0'
    id("org.jetbrains.kotlin.android") apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
}

// ... 文件的其他部分保持不變 ...
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
