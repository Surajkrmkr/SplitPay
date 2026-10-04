package com.splitpay.expensetracker

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.os.Parcelable
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.TimeZone
import java.util.UUID
import kotlin.math.max

class MainActivity : FlutterFragmentActivity() {
    private val shareChannelName = "com.splitpay.expensetracker/shared_images"
    private val shareEventsName = "$shareChannelName/events"
    private val sharePreferences by lazy {
        getSharedPreferences("shared_image_import", MODE_PRIVATE)
    }
    private var shareEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeExpiredSharedImages()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.splitpay.expensetracker/timezone",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getLocalTimezone") {
                result.success(TimeZone.getDefault().id)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingImages" -> result.success(
                    mapOf(
                        "paths" to readPendingImages(),
                        "omittedCount" to sharePreferences.getInt(PENDING_OMITTED_KEY, 0),
                    ),
                )
                "prepareImageForOcr" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error(
                            "image_path_missing",
                            "Shared image path is missing",
                            null,
                        )
                    } else {
                        when (val preparation = prepareImageForOcr(path)) {
                            is ImagePreparationResult.Success ->
                                result.success(preparation.path)
                            is ImagePreparationResult.Failure -> {
                                Log.w(LOG_TAG, "Image preparation failed at ${preparation.code}")
                                result.error(
                                    preparation.code,
                                    "Shared image could not be prepared for OCR",
                                    null,
                                )
                            }
                        }
                    }
                }
                "deleteImages" -> {
                    if (deleteSharedImages(call.argument<List<String>>("paths").orEmpty())) {
                        result.success(null)
                    } else {
                        result.error(
                            "share_delete_failed",
                            "Shared image cleanup failed",
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareEventsName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink,
            ) {
                shareEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                shareEventSink = null
            }
        })
        handleSharedIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent == null ||
            (intent.action != Intent.ACTION_SEND &&
                intent.action != Intent.ACTION_SEND_MULTIPLE)
        ) return
        val mimeType = intent.type.orEmpty()
        if (!mimeType.startsWith("image/")) {
            Log.w(LOG_TAG, "Rejected shared content with unsupported MIME type")
            shareEventSink?.error("unsupported_share", "Unsupported shared content", null)
            return
        }

        val allUris = sharedUris(intent).distinct()
        Log.i(LOG_TAG, "Received image share containing ${allUris.size} image URI(s)")
        val uris = allUris.take(MAX_SHARED_IMAGES)
        val saved = uris.mapNotNull(::copySharedImage)
        if (saved.isEmpty()) {
            Log.w(LOG_TAG, "Could not copy any image from shared content")
            shareEventSink?.error("image_unavailable", "Shared image unavailable", null)
            return
        }

        val pending = readPendingImages().toMutableList()
        pending.addAll(saved)
        val omittedCount = allUris.size - saved.size
        sharePreferences.edit()
            .putString(PENDING_IMAGES_KEY, JSONArray(pending).toString())
            .putInt(
                PENDING_OMITTED_KEY,
                sharePreferences.getInt(PENDING_OMITTED_KEY, 0) + omittedCount,
            )
            .apply()
        Log.i(LOG_TAG, "Staged ${saved.size} shared image(s); omitted $omittedCount")
        shareEventSink?.success(
            mapOf("paths" to saved, "omittedCount" to omittedCount),
        )
    }

    private fun sharedUris(intent: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()
        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let(uris::add)
            }
        }
        @Suppress("DEPRECATION")
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val streams = intent.getParcelableArrayListExtra<Parcelable>(Intent.EXTRA_STREAM)
            streams?.filterIsInstance<Uri>()?.let(uris::addAll)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let(uris::add)
        }
        return uris.filter { uri ->
            uri.scheme == "content" || uri.scheme == "file"
        }
    }

    private fun copySharedImage(uri: Uri): String? {
        val directory = sharedImageDirectory()
        if (!directory.exists() && !directory.mkdirs()) return null
        val destination = File(directory, "${UUID.randomUUID()}.image")
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { source ->
                FileOutputStream(destination).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > MAX_IMAGE_BYTES) {
                            throw IOException("Shared image exceeds size limit")
                        }
                        output.write(buffer, 0, count)
                    }
                    if (total == 0L) throw IOException("Empty shared image")
                }
            }
            destination.absolutePath
        } catch (_: Exception) {
            destination.delete()
            Log.w(LOG_TAG, "Could not stage a shared image in app cache")
            null
        }
    }

    private fun prepareImageForOcr(path: String): ImagePreparationResult {
        val directory = try {
            sharedImageDirectory().canonicalFile
        } catch (_: IOException) {
            return ImagePreparationResult.Failure("image_cache_unavailable")
        }
        val source = try {
            File(path).canonicalFile
        } catch (_: IOException) {
            return ImagePreparationResult.Failure("image_path_invalid")
        }
        if (source.parentFile != directory) {
            return ImagePreparationResult.Failure("image_path_invalid")
        }
        if (!source.isFile) {
            return ImagePreparationResult.Failure("image_file_missing")
        }
        if (source.length() <= 0) {
            return ImagePreparationResult.Failure("image_file_empty")
        }
        if (source.length() > MAX_IMAGE_BYTES) {
            return ImagePreparationResult.Failure("image_file_too_large")
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return ImagePreparationResult.Failure("image_format_unsupported")
        }

        val options = BitmapFactory.Options()
        var sampleSize = 1
        while (max(bounds.outWidth, bounds.outHeight) / sampleSize > MAX_OCR_DIMENSION) {
            sampleSize *= 2
        }
        options.inSampleSize = sampleSize
        options.inPreferredConfig = Bitmap.Config.ARGB_8888
        val bitmap = BitmapFactory.decodeFile(source.absolutePath, options)
        if (bitmap == null) {
            return ImagePreparationResult.Failure("image_bitmap_decode_failed")
        }

        val destination = File(directory, "${UUID.randomUUID()}.jpg")
        return try {
            FileOutputStream(destination).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 92, output)) {
                    return@use false
                }
                output.flush()
                true
            }
                .let { encoded ->
                    if (!encoded || destination.length() <= 0) {
                        destination.delete()
                        ImagePreparationResult.Failure("image_jpeg_encode_failed")
                    } else {
                        val outputBounds = BitmapFactory.Options().apply {
                            inJustDecodeBounds = true
                        }
                        BitmapFactory.decodeFile(destination.absolutePath, outputBounds)
                        if (outputBounds.outWidth <= 0 || outputBounds.outHeight <= 0) {
                            destination.delete()
                            ImagePreparationResult.Failure("image_jpeg_verify_failed")
                        } else {
                            ImagePreparationResult.Success(destination.absolutePath)
                        }
                    }
                }
        } catch (_: Exception) {
            destination.delete()
            ImagePreparationResult.Failure("image_jpeg_write_failed")
        } finally {
            bitmap.recycle()
        }
    }

    private fun readPendingImages(): List<String> {
        val encoded = sharePreferences.getString(PENDING_IMAGES_KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(encoded)
            (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun deleteSharedImages(paths: List<String>): Boolean {
        val directory = sharedImageDirectory().canonicalFile
        val deletedPaths = mutableSetOf<String>()
        for (path in paths) {
            val file = try {
                File(path).canonicalFile
            } catch (_: IOException) {
                return false
            }
            if (file.parentFile != directory) return false
            if (file.exists() && !file.delete()) return false
            deletedPaths.add(file.absolutePath)
        }
        val remaining = readPendingImages().filterNot { it in deletedPaths }
        if (remaining.isEmpty()) {
            sharePreferences.edit()
                .remove(PENDING_IMAGES_KEY)
                .remove(PENDING_OMITTED_KEY)
                .apply()
        } else {
            sharePreferences.edit()
                .putString(PENDING_IMAGES_KEY, JSONArray(remaining).toString())
                .apply()
        }
        return true
    }

    private fun sharedImageDirectory() = File(cacheDir, "shared_upi_images")

    private fun removeExpiredSharedImages() {
        val directory = sharedImageDirectory()
        val expiry = System.currentTimeMillis() - MAX_PENDING_AGE_MS
        directory.listFiles()?.forEach { file ->
            if (file.lastModified() < expiry) file.delete()
        }
    }

    companion object {
        private const val LOG_TAG = "SplitPayShare"
        private const val PENDING_IMAGES_KEY = "pending_paths"
        private const val PENDING_OMITTED_KEY = "pending_omitted_count"
        private const val MAX_SHARED_IMAGES = 5
        private const val MAX_IMAGE_BYTES = 25L * 1024 * 1024
        private const val MAX_OCR_DIMENSION = 2600
        private const val MAX_PENDING_AGE_MS = 24L * 60 * 60 * 1000
    }

    private sealed interface ImagePreparationResult {
        data class Success(val path: String) : ImagePreparationResult
        data class Failure(val code: String) : ImagePreparationResult
    }
}
