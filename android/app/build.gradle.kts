import com.android.build.api.variant.SourceDirectories
import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction

plugins {
    id("dev.flutter.flutter-gradle-plugin")
    id("com.android.application")
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

// AGP 8.x+ forbids passing a Provider to the old SourceSet srcDir() API.
// Define the task with a proper @OutputDirectory DirectoryProperty so that
// addGeneratedSourceDirectory (via the androidComponents Variant API) can wire
// it up without touching the deprecated SourceSet path.
abstract class ExtractJackcessResTask : DefaultTask() {
    @get:InputFiles
    abstract val jackcessConfig: org.gradle.api.file.ConfigurableFileCollection

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun extract() {
        val outDir = outputDir.get().asFile
        outDir.mkdirs()

        val jackcessJar = jackcessConfig.files.firstOrNull {
            it.name.startsWith("jackcess-") && it.extension == "jar"
        } ?: error("Jackcess dependency was not resolved")

        project.copy {
            from(project.zipTree(jackcessJar)) {
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
            into(outDir)
        }
    }
}

val extractJackcessAndroidResources by tasks.registering(ExtractJackcessResTask::class) {
    jackcessConfig.from(jackcessResourceExtraction)
    outputDir.set(layout.buildDirectory.dir("generated/jackcess-res"))
}

// Wire the generated res directory into every variant using the AGP Variant API.
// addGeneratedSourceDirectory requires a task with a DirectoryProperty output,
// which is why we use the typed ExtractJackcessResTask above instead of a plain
// task with outputs.dir().
androidComponents {
    onVariants { variant ->
        variant.sources.res?.addGeneratedSourceDirectory(
            extractJackcessAndroidResources,
            ExtractJackcessResTask::outputDir,
        )
    }
}
