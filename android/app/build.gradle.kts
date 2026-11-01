plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.visual_song_book"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.visual_song_book"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

val jackcessCoordinate = "com.healthmarketscience.jackcess:jackcess:4.0.12"

dependencies {
    // Pure-Java Access reader bundled into Android builds for .vsb/.mdb imports.
    implementation(jackcessCoordinate)
    // Jackcess uses java.nio.file; backport it for the app's Android 21 minimum.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.0.2")
}

val jackcessResourceExtraction by configurations.creating {
    isCanBeConsumed = false
    isCanBeResolved = true
}

dependencies.add(jackcessResourceExtraction.name, jackcessCoordinate)

val jackcessAndroidResources = layout.buildDirectory.dir("generated/jackcess-res")
android.sourceSets.getByName("main").res.srcDir(jackcessAndroidResources)

val extractJackcessAndroidResources by tasks.registering {
    inputs.files(jackcessResourceExtraction)
    outputs.dir(jackcessAndroidResources)

    doLast {
        val jackcessJar = jackcessResourceExtraction.files.firstOrNull {
            it.name.startsWith("jackcess-") && it.extension == "jar"
        } ?: error("Jackcess dependency was not resolved")
        copy {
            from(zipTree(jackcessJar)) {
                include("com/healthmarketscience/jackcess/*.txt")
                include("com/healthmarketscience/jackcess/*.mdb")
                include("com/healthmarketscience/jackcess/*.accdb")
                eachFile {
                    val extension = name.substringAfterLast('.', "").lowercase()
                    val baseName = name.substringBeforeLast('.', name)
                        .lowercase()
                        .replace(Regex("[^a-z0-9_]"), "_")
                    path = "raw/$baseName.$extension"
                }
                includeEmptyDirs = false
            }
            into(jackcessAndroidResources)
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(extractJackcessAndroidResources)
}
