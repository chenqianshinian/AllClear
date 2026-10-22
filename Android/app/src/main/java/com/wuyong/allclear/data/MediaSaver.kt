package com.wuyong.allclear.data

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File

/**
 * 下载结果文件并保存到系统相册 / 下载目录。
 * Android 10+ 使用 MediaStore（无需存储权限），Android 9 及以下使用公共目录（需 WRITE_EXTERNAL_STORAGE）。
 */
object MediaSaver {

    private val client = OkHttpClient()

    fun download(context: Context, url: String, filename: String): File {
        val safeName = filename.substringAfterLast('/').ifBlank { "allclear_${System.currentTimeMillis()}" }
        val dir = File(context.cacheDir, "results").apply { mkdirs() }
        val target = File(dir, safeName)
        val request = Request.Builder().url(url).build()
        client.newCall(request).execute().use { resp ->
            if (!resp.isSuccessful) throw ApiException("下载失败（${resp.code}）", resp.code)
            resp.body?.byteStream()?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: throw ApiException("下载内容为空")
        }
        return target
    }

    fun mimeOf(file: File, isVideo: Boolean): String = when {
        isVideo -> "video/mp4"
        file.extension.lowercase() == "png" -> "image/png"
        file.extension.lowercase() == "webp" -> "image/webp"
        file.extension.lowercase() == "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        file.extension.lowercase() == "doc" -> "application/msword"
        file.extension.lowercase() == "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        file.extension.lowercase() == "ppt" -> "application/vnd.ms-powerpoint"
        file.extension.lowercase() == "pdf" -> "application/pdf"
        else -> "image/jpeg"
    }

    /** 保存图片或视频到相册 */
    fun saveToGallery(context: Context, file: File, isVideo: Boolean): String {
        val mime = mimeOf(file, isVideo)
        val collection = if (isVideo) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    if (isVideo) Environment.DIRECTORY_MOVIES + "/AllClear"
                    else Environment.DIRECTORY_PICTURES + "/AllClear"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(collection, values) ?: throw ApiException("保存失败")
        resolver.openOutputStream(uri)?.use { output ->
            file.inputStream().use { input -> input.copyTo(output) }
        } ?: throw ApiException("保存失败")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return file.name
    }

    /** 保存文档到“下载/AllClear” */
    fun saveToDownloads(context: Context, file: File): String {
        val mime = mimeOf(file, isVideo = false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/AllClear")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = context.contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values) ?: throw ApiException("保存失败")
            resolver.openOutputStream(uri)?.use { output ->
                file.inputStream().use { input -> input.copyTo(output) }
            } ?: throw ApiException("保存失败")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "下载/AllClear/${file.name}"
        }
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "AllClear"
        )
        dir.mkdirs()
        val target = File(dir, file.name)
        file.copyTo(target, overwrite = true)
        return target.absolutePath
    }
}
