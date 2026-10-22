package com.wuyong.allclear.ui

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.wuyong.allclear.data.ApiClient
import com.wuyong.allclear.data.ApiException
import com.wuyong.allclear.data.UserInfo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

enum class FileKind { IMAGE, VIDEO, DOCUMENT }

/** 选中的本地文件 */
data class PickedFile(
    val file: File,
    val name: String,
    val kind: FileKind,
    val sizeMb: Double
) {
    val isVideo: Boolean get() = kind == FileKind.VIDEO
    val isImage: Boolean get() = kind == FileKind.IMAGE
}

/** 处理结果 */
data class ResultFile(
    val remoteUrl: String,
    val name: String,
    val kind: FileKind
) {
    val isVideo: Boolean get() = kind == FileKind.VIDEO
    val isImage: Boolean get() = kind == FileKind.IMAGE
}

data class ToastMsg(val text: String)

class MainViewModel(app: Application) : AndroidViewModel(app) {

    private val context: Context get() = getApplication()

    var isLogin by mutableStateOf(ApiClient.hasToken())
        private set
    var user by mutableStateOf<UserInfo?>(ApiClient.cachedUser(app))
        private set

    var mode by mutableStateOf(0) // 0 图片与视频，1 PDF与文档
        private set

    val images = mutableStateListOf<PickedFile>()
    val documents = mutableStateListOf<PickedFile>()
    var video by mutableStateOf<PickedFile?>(null)
        private set

    /** 视频框选页正在编辑的视频；非 null 时主界面切换到框选页 */
    var editingVideo by mutableStateOf<PickedFile?>(null)
        private set

    var isProcessing by mutableStateOf(false)
        private set
    var progress by mutableStateOf(0)
        private set
    val results = mutableStateListOf<ResultFile>()
    var stageText by mutableStateOf("")
        private set

    var toast by mutableStateOf<ToastMsg?>(null)

    /** 首页「AI 超强去水印」开关；放 VM 里，切 Tab 回来不会丢 */
    var useAi by mutableStateOf(false)

    /** 文档「水印文字」提示词；处理前与结果重试共用同一份 */
    var docPrompt by mutableStateOf("")

    /** 审核模式：后端开启时隐藏充值入口 */
    var inReview by mutableStateOf(false)
        private set

    val points: Int get() = user?.points ?: 0
    val isVip: Boolean get() = user?.isVip == true
    // 与官网 / 鸿蒙端 H5 的额度规则一致：
    // 免费 3 个 / 图 5MB / 视频 10MB / 文档 10MB；会员 20 个 / 20MB / 50MB / 50MB
    val maxSelectCount: Int get() = if (isVip) 20 else 3
    val maxImageMb: Double get() = if (isVip) 20.0 else 5.0
    val maxVideoMb: Double get() = if (isVip) 50.0 else 10.0
    val maxDocumentMb: Double get() = if (isVip) 50.0 else 10.0

    fun switchMode(target: Int) {
        if (mode == target) return
        clearAll()
        mode = target
    }

    fun clearAll() {
        images.forEach { it.file.delete() }
        documents.forEach { it.file.delete() }
        video?.file?.delete()
        images.clear()
        documents.clear()
        video = null
        results.clear()
        progress = 0
        stageText = ""
        // 与鸿蒙端一致：清空时一并重置提示词
        docPrompt = ""
    }

    fun clearResult() {
        results.clear()
        progress = 0
        stageText = ""
    }

    fun showToast(text: String) {
        toast = ToastMsg(text)
    }

    fun consumeToast() {
        toast = null
    }

    // ---------- 文件选择 ----------

    fun addImages(uris: List<Uri>) {
        viewModelScope.launch {
            val added = withContext(Dispatchers.IO) {
                uris.mapNotNull { copyUri(it, fallback = FileKind.IMAGE) }
            }
            for (item in added) {
                when {
                    images.size >= maxSelectCount -> {
                        item.file.delete()
                        showToast("最多只能选择 $maxSelectCount 个文件")
                        break
                    }
                    item.sizeMb > maxImageMb -> {
                        item.file.delete()
                        showToast("包含超过 ${maxImageMb.toInt()}MB 的图片，请重新选择")
                        continue
                    }
                    else -> images.add(item)
                }
            }
            removeVideo()
            clearResult()
        }
    }

    fun setVideoUri(uri: Uri) {
        viewModelScope.launch {
            val item = withContext(Dispatchers.IO) { copyUri(uri, fallback = FileKind.VIDEO) }
            if (item == null) {
                showToast("读取视频失败，请重试")
                return@launch
            }
            val limit = maxVideoMb
            if (item.sizeMb > limit) {
                item.file.delete()
                showToast("视频超过 ${limit.toInt()}MB 限制，请重新选择")
                return@launch
            }
            images.forEach { it.file.delete() }
            images.clear()
            video?.file?.delete()
            video = item
            // 选完视频直接进入框选页（与鸿蒙端 pages/video-edit 一致）
            editingVideo = item
            clearResult()
        }
    }

    fun closeVideoEditor() {
        editingVideo = null
    }

    /** 框选页提交：regionsJson 形如 [{"x":0,"y":0,"width":100,"height":40}] */
    fun processVideoRegions(regionsJson: String, onDone: (Boolean) -> Unit) {
        val item = editingVideo ?: return
        if (!isLogin) {
            showToast("请先登录")
            onDone(false)
            return
        }
        if (points <= 0) {
            showToast("次数不足！处理 1 个视频需要 1 次，请前往“我的”页面获取")
            onDone(false)
            return
        }
        viewModelScope.launch {
            isProcessing = true
            progress = 0
            stageText = "正在上传并处理视频…"
            val outcome = runCatching {
                withContext(Dispatchers.IO) {
                    ApiClient.removeMedia(
                        file = item.file,
                        isVideo = true,
                        regions = regionsJson,
                        onProgress = { p -> progress = p }
                    )
                }
            }
            isProcessing = false
            stageText = ""
            outcome.onSuccess { url ->
                progress = 100
                results.clear()
                results.add(ResultFile(remoteUrl = url, name = item.name, kind = FileKind.VIDEO))
                showToast("处理完成")
                refreshUser()
                onDone(true)
            }.onFailure {
                showToast(it.message ?: "处理失败，请稍后重试")
                onDone(false)
            }
        }
    }

    fun addDocuments(uris: List<Uri>) {
        viewModelScope.launch {
            val added = withContext(Dispatchers.IO) {
                uris.mapNotNull { copyUri(it, fallback = FileKind.DOCUMENT) }
            }
            for (item in added) {
                if (documents.size >= maxSelectCount) {
                    item.file.delete()
                    showToast("最多只能选择 $maxSelectCount 个文件")
                    break
                }
                if (item.sizeMb > maxDocumentMb) {
                    item.file.delete()
                    showToast("包含超过 ${maxDocumentMb.toInt()}MB 的文档，请重新选择")
                    continue
                }
                documents.add(item)
            }
            // 与鸿蒙端一致：重新选文档时清空上一次的提示词
            if (added.isNotEmpty()) docPrompt = ""
            clearResult()
        }
    }

    fun removeImage(item: PickedFile) {
        images.remove(item)
        item.file.delete()
        if (images.isEmpty()) clearResult()
    }

    fun removeVideo() {
        video?.file?.delete()
        video = null
        clearResult()
    }

    fun removeDocument(item: PickedFile) {
        documents.remove(item)
        item.file.delete()
        if (documents.isEmpty()) clearResult()
    }

    private fun copyUri(uri: Uri, fallback: FileKind): PickedFile? = runCatching {
        val resolver = context.contentResolver
        val mime = resolver.getType(uri).orEmpty()
        val display = queryName(uri)
        val kind = when {
            mime.startsWith("image/") -> FileKind.IMAGE
            mime.startsWith("video/") -> FileKind.VIDEO
            else -> fallback
        }
        val ext = when {
            display.contains('.') -> display.substringAfterLast('.')
            mime.startsWith("image/") -> mime.substringAfter('/')
            mime.startsWith("video/") -> "mp4"
            else -> "bin"
        }
        val safeName = display.substringBeforeLast('.').ifBlank { "file" }
        val target = File(context.cacheDir, "upload_${System.currentTimeMillis()}_$safeName.$ext")
        resolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        PickedFile(
            file = target,
            name = if (display.contains('.')) display else "$safeName.$ext",
            kind = kind,
            sizeMb = target.length() / 1024.0 / 1024.0
        )
    }.getOrNull()

    private fun queryName(uri: Uri): String {
        val projection = arrayOf(android.provider.OpenableColumns.DISPLAY_NAME)
        context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    val name = cursor.getString(index)
                    if (!name.isNullOrBlank()) return name
                }
            }
        }
        return "file_${System.currentTimeMillis()}"
    }

    // ---------- 登录 / 用户 ----------

    fun refreshUser() {
        if (!isLogin) return
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { ApiClient.me(context) } }
                .onSuccess {
                    user = it
                    ApiClient.saveCachedUser(context, it)
                }
                .onFailure {
                    if (it is ApiException && it.status == 401) {
                        // token 已失效：连本地 token / 用户缓存一起清掉，
                        // 否则下次冷启动仍会因 hasToken() 为 true 而进入「假登录」状态
                        ApiClient.logout(context)
                        isLogin = false
                        user = null
                    }
                }
        }
    }

    fun loadSystemConfig() {
        viewModelScope.launch {
            val remote = withContext(Dispatchers.IO) {
                runCatching { ApiClient.inReview() }.getOrNull()
            }
            // 网络异常时不要误开充值入口：保持上次成功读取的值
            if (remote != null) inReview = remote
        }
    }

    fun deleteAccount(onDone: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) { ApiClient.deleteAccount(context) }
            }
            result.onSuccess {
                isLogin = false
                user = null
                onDone(true, "账号已注销")
            }.onFailure {
                onDone(false, it.message ?: "注销失败，请稍后重试")
            }
        }
    }

    fun login(email: String, password: String, onDone: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) { ApiClient.login(context, email.trim(), password) }
            }
            result.onSuccess {
                user = it
                isLogin = true
                ApiClient.saveCachedUser(context, it)
                onDone(true, "登录成功")
            }.onFailure {
                onDone(false, it.message ?: "登录失败，请稍后重试")
            }
        }
    }

    fun register(email: String, password: String, onDone: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) { ApiClient.register(email.trim(), password) }
            }
            result.onSuccess {
                onDone(true, "注册成功，请登录")
            }.onFailure {
                onDone(false, it.message ?: "注册失败，请稍后重试")
            }
        }
    }

    fun checkin(onDone: (Boolean, String) -> Unit) {
        if (!isLogin) {
            onDone(false, "请先登录")
            return
        }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { ApiClient.checkin() } }
                .onSuccess { (message, balance) ->
                    user = user?.copy(points = balance) ?: user
                    user?.let { ApiClient.saveCachedUser(context, it) }
                    onDone(true, message)
                }
                .onFailure { onDone(false, it.message ?: "签到失败，请检查网络") }
        }
    }

    fun logout() {
        ApiClient.logout(context)
        isLogin = false
        user = null
    }

    /** 扫码登录电脑版：把扫码得到的 sceneId 提交给后端确认 */
    fun confirmScanLogin(sceneId: String, onDone: (Boolean, String) -> Unit) {
        if (!isLogin) {
            onDone(false, "请先登录")
            return
        }
        if (sceneId.isBlank()) {
            onDone(false, "无效的登录二维码")
            return
        }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { ApiClient.confirmScanLogin(sceneId) } }
                .onSuccess { onDone(true, "电脑端已成功登录") }
                .onFailure { onDone(false, it.message ?: "二维码已过期或无效") }
        }
    }

    // ---------- 首启隐私合规 ----------

    private val privacyPrefs get() = context.getSharedPreferences("allclear_privacy", Context.MODE_PRIVATE)

    fun hasAgreedPrivacy(): Boolean = privacyPrefs.getBoolean("agreed", false)

    fun setAgreedPrivacy() {
        privacyPrefs.edit().putBoolean("agreed", true).apply()
    }

    fun exitApp() {
        (context as? android.app.Activity)?.finishAffinity()
    }

    // ---------- 去水印 ----------

    fun currentFiles(): List<PickedFile> =
        if (mode == 0) {
            video?.let { listOf(it) } ?: images.toList()
        } else {
            documents.toList()
        }

    fun process(useAi: Boolean = false, prompt: String = "") {
        val files = currentFiles()
        if (files.isEmpty()) {
            showToast("请先选择文件")
            return
        }
        if (!isLogin) {
            showToast("请先登录")
            return
        }
        val available = points
        if (available <= 0) {
            showToast("次数不足！处理 1 个文件需要 1 次，请前往“我的”页面获取")
            return
        }
        val pending = if (available < files.size) {
            showToast("次数不足，剩余 $available 次，本次只处理 $available 个")
            files.take(available)
        } else {
            files
        }

        viewModelScope.launch {
            isProcessing = true
            results.clear()
            progress = 0
            var failed = 0
            var lastError = ""

            pending.forEachIndexed { index, item ->
                stageText = if (pending.size > 1) {
                    "正在处理 ${index + 1}/${pending.size}：${item.name}"
                } else {
                    "正在上传并处理，请稍候…"
                }
                val base = index * 100 / pending.size
                val step = 100 / pending.size
                val outcome = runCatching {
                    withContext(Dispatchers.IO) {
                        when (item.kind) {
                            FileKind.VIDEO -> ApiClient.removeMedia(
                                file = item.file,
                                isVideo = true,
                                onProgress = { p -> progress = base + p * step / 100 }
                            )
                            FileKind.IMAGE -> ApiClient.removeMedia(
                                file = item.file,
                                isVideo = false,
                                useAi = useAi,
                                prompt = prompt.ifBlank { null },
                                onProgress = { p -> progress = base + p * step / 100 }
                            )
                            FileKind.DOCUMENT -> ApiClient.removeDocument(
                                file = item.file,
                                prompt = prompt,
                                onProgress = { p -> progress = base + p * step / 100 }
                            )
                        }
                    }
                }
                outcome.onSuccess { url ->
                    results.add(ResultFile(remoteUrl = url, name = item.name, kind = item.kind))
                }.onFailure {
                    failed++
                    lastError = it.message.orEmpty()
                }
            }

            progress = 100
            isProcessing = false
            stageText = ""
            if (results.isEmpty()) {
                showToast(lastError.ifBlank { "处理失败，请稍后重试" })
            } else if (failed > 0) {
                showToast("$failed 个文件处理失败，失败次数不扣除")
            } else {
                showToast("处理完成")
            }
            refreshUser()
        }
    }
}
