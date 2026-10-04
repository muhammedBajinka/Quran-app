package com.bajinka.quran

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val DOWNLOAD_CHANNEL = "quran_life/downloads"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadMedia" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")

                    if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                        result.error(
                            "INVALID_DOWNLOAD",
                            "A media URL and file name are required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val downloadId = enqueueDownload(
                            url = url,
                            fileName = fileName,
                            mimeType = mimeType
                        )

                        result.success(downloadId)
                    } catch (error: Exception) {
                        result.error(
                            "DOWNLOAD_FAILED",
                            error.message ?: "Unable to start download.",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun enqueueDownload(
        url: String,
        fileName: String,
        mimeType: String?
    ): Long {
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(fileName)
            .setDescription("Downloading from Quran Life")
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            .setDestinationInExternalPublicDir(
                Environment.DIRECTORY_DOWNLOADS,
                fileName
            )
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)

        if (!mimeType.isNullOrBlank()) {
            request.setMimeType(mimeType)
        }

        val manager =
            getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

        return manager.enqueue(request)
    }
}
