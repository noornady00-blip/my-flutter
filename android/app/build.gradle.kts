import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mahameek.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mahameek.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties["keyAlias"] as String?
            val keyPasswordProp = keystoreProperties["keyPassword"] as String?
            val storeFileProp = keystoreProperties["storeFile"] as String?
            val storePasswordProp = keystoreProperties["storePassword"] as String?

            val keystoreFile = if (storeFileProp != null) {
                val f1 = file(storeFileProp)
                val f2 = rootProject.file(storeFileProp)
                if (f1.exists()) f1 else if (f2.exists()) f2 else null
            } else null

            if (keyAliasProp != null && keystoreFile != null) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = keystoreFile
                storePassword = storePasswordProp
            } else {
                // Fallback to debug signing config for CI / development if release key is absent
                val debugConfig = signingConfigs.getByName("debug")
                val debugFile = debugConfig.storeFile ?: file(System.getProperty("user.home") + "/.android/debug.keystore")
                if (!debugFile.exists()) {
                    debugFile.parentFile?.mkdirs()
                    try {
                        ProcessBuilder(
                            "keytool", "-genkey", "-v",
                            "-keystore", debugFile.absolutePath,
                            "-storepass", "android",
                            "-alias", "androiddebugkey",
                            "-keypass", "android",
                            "-keyalg", "RSA",
                            "-keysize", "2048",
                            "-validity", "10000",
                            "-dname", "CN=Android Debug,O=Android,C=US"
                        ).redirectErrorStream(true).start().waitFor()
                    } catch (e: Exception) {
                        println("Note: could not auto-create debug keystore: ${e.message}")
                    }
                }
                keyAlias = debugConfig.keyAlias
                keyPassword = debugConfig.keyPassword
                storeFile = debugFile
                storePassword = debugConfig.storePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            ndk {
                debugSymbolLevel = "none"
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
