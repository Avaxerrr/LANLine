package com.lanline.lanline

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lanline.lanline/mediastore"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")!!
                    val fileName = call.argument<String>("fileName")!!
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    try {
                        val uri = saveFileToDownloads(sourcePath, fileName, mimeType)
                        result.success(uri?.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                }
                "deleteFromDownloads" -> {
                    val fileName = call.argument<String>("fileName")!!
                    try {
                        val deleted = deleteFileFromDownloads(fileName)
                        result.success(deleted)
                    } catch (e: Exception) {
                        result.error("DELETE_ERROR", e.message, null)
                    }
                }
                "getDownloadsPath" -> {
                    val path = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        .absolutePath + "/LANLine"
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveFileToDownloads(sourcePath: String, fileName: String, mimeType: String): Uri? {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ — use MediaStore
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/LANLine")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            uri?.let {
                resolver.openOutputStream(it)?.use { output ->
                    sourceFile.inputStream().use { input ->
                        input.copyTo(output)
                    }
                }
                contentValues.clear()
                contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(it, contentValues, null, null)
            }

            // Delete the temp file from app storage
            sourceFile.delete()
            return uri
        } else {
            // Android 9 and below — direct file copy
            val downloadsDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "LANLine"
            )
            if (!downloadsDir.exists()) downloadsDir.mkdirs()

            val destFile = File(downloadsDir, fileName)
            sourceFile.copyTo(destFile, overwrite = true)
            sourceFile.delete()
            return Uri.fromFile(destFile)
        }
    }

    private fun deleteFileFromDownloads(fileName: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(fileName)
            val deleted = resolver.delete(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                selection,
                selectionArgs
            )
            return deleted > 0
        } else {
            val file = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "LANLine/$fileName"
            )
            return if (file.exists()) file.delete() else false
        }
    }
}
