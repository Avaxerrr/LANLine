package com.lanline.lanline

import android.content.ContentValues
import android.content.Context
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lanline.lanline/mediastore"
    private val PROXIMITY_CHANNEL = "com.lanline.lanline/proximity"
    private var proximityWakeLock: PowerManager.WakeLock? = null
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var toneGenerator: ToneGenerator? = null
    private var ringbackThread: Thread? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Proximity / call audio channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROXIMITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (proximityWakeLock == null) {
                            proximityWakeLock = powerManager.newWakeLock(
                                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                                "lanline:proximity"
                            )
                        }
                        if (proximityWakeLock?.isHeld == false) {
                            proximityWakeLock?.acquire()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PROXIMITY_ERROR", e.message, null)
                    }
                }
                "release" -> {
                    try {
                        if (proximityWakeLock?.isHeld == true) {
                            proximityWakeLock?.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
                        }
                        proximityWakeLock = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PROXIMITY_ERROR", e.message, null)
                    }
                }
                "startRingtone" -> {
                    try {
                        // Play system ringtone
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                        ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                        ringtone?.isLooping = true
                        ringtone?.play()

                        // Vibrate with call pattern
                        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            vm.defaultVibrator
                        } else {
                            @Suppress("DEPRECATION")
                            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                        }
                        val pattern = longArrayOf(0, 1000, 1000) // vibrate 1s, pause 1s, repeat
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator?.vibrate(pattern, 0)
                        }

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.message, null)
                    }
                }
                "stopRingtone" -> {
                    try {
                        ringtone?.stop()
                        ringtone = null
                        vibrator?.cancel()
                        vibrator = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.message, null)
                    }
                }
                "startRingback" -> {
                    try {
                        // Ring-back tone: the "rrrring... rrrring..." the caller hears
                        ringbackThread = Thread {
                            try {
                                toneGenerator = ToneGenerator(AudioManager.STREAM_VOICE_CALL, 80)
                                while (!Thread.currentThread().isInterrupted) {
                                    toneGenerator?.startTone(ToneGenerator.TONE_SUP_RINGTONE, 1000)
                                    Thread.sleep(3000) // ring for 1s, pause for 2s
                                }
                            } catch (_: InterruptedException) {
                                // Thread interrupted — clean exit
                            } catch (_: Exception) {}
                        }
                        ringbackThread?.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RINGBACK_ERROR", e.message, null)
                    }
                }
                "stopRingback" -> {
                    try {
                        ringbackThread?.interrupt()
                        ringbackThread = null
                        toneGenerator?.release()
                        toneGenerator = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RINGBACK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // MediaStore channel
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
