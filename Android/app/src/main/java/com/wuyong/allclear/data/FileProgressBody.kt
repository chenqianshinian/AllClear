package com.wuyong.allclear.data

import okhttp3.MediaType
import okhttp3.RequestBody
import okio.BufferedSink
import java.io.File
import java.io.FileInputStream

/**
 * 文件上传请求体，边读边写并回报进度。
 * 通过 MultipartBody.addFormDataPart(name, filename, body) 使用。
 */
class FileProgressBody(
    private val file: File,
    private val mediaType: MediaType?,
    private val onProgress: ((Int) -> Unit)?
) : RequestBody() {

    override fun contentType(): MediaType? = mediaType

    override fun contentLength(): Long = file.length()

    override fun writeTo(sink: BufferedSink) {
        val total = file.length().coerceAtLeast(1L)
        var uploaded = 0L
        FileInputStream(file).use { input ->
            val buffer = ByteArray(BUFFER_SIZE)
            var read: Int
            while (input.read(buffer).also { read = it } != -1) {
                sink.write(buffer, 0, read)
                uploaded += read
                onProgress?.invoke((uploaded * 100 / total).toInt().coerceIn(0, 100))
            }
        }
        onProgress?.invoke(100)
    }

    companion object {
        private const val BUFFER_SIZE = 32 * 1024
    }
}
