package com.example.visual_song_book

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "visual_song_book/vsb_converter",
        ).setMethodCallHandler { call, result ->
            if (call.method != "convertAccessFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val inputPath = call.argument<String>("path")
            if (inputPath.isNullOrBlank()) {
                result.error("missing_path", "No Access file path was provided.", null)
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val outputPath = VsbAccessConverter.convert(inputPath, cacheDir)
                    Handler(Looper.getMainLooper()).post { result.success(outputPath) }
                } catch (error: Exception) {
                    Handler(Looper.getMainLooper()).post {
                        result.error(
                            "conversion_failed",
                            error.message ?: "Could not read this Access songbook.",
                            null,
                        )
                    }
                }
            }.start()
        }
    }
}
