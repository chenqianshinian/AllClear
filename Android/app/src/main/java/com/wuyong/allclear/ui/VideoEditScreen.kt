package com.wuyong.allclear.ui

import android.media.MediaMetadataRetriever
import android.net.Uri
import android.widget.VideoView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.activity.compose.BackHandler
import com.wuyong.allclear.data.MediaSaver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 视频框选页：在视频画面上手动框出水印位置，再把坐标换算成原视频像素上传。
 * 交互与鸿蒙端 pages/video-edit/index.tsx、iOS VideoEditView 保持一致。
 */
@Composable
fun VideoEditScreen(
    vm: MainViewModel,
    file: PickedFile,
    onExit: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val configuration = LocalConfiguration.current

    // 原始视频像素尺寸（已按旋转角修正）
    var videoSize by remember { mutableStateOf(Size.Zero) }
    LaunchedEffect(file.file.absolutePath) {
        videoSize = withContext(Dispatchers.IO) { readDisplaySize(file.file) }
    }

    val boxes = remember { mutableStateListOf<Rect>() }
    var drawing by remember { mutableStateOf<Rect?>(null) }
    var dragStart by remember { mutableStateOf<Offset?>(null) }

    var resultUrl by remember { mutableStateOf<String?>(null) }
    var isSaving by remember { mutableStateOf(false) }

    val aspect = if (videoSize.height > 0f) videoSize.width / videoSize.height else 16f / 9f
    val displayWidth = (configuration.screenWidthDp.dp - 40.dp).coerceAtLeast(200.dp)
    val displayHeight = displayWidth / aspect.coerceAtLeast(0.2f)

    // 系统返回键：处理中不响应，避免中断上传
    BackHandler(enabled = !vm.isProcessing) { onExit() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AcColor.PageBg)
            .verticalScroll(rememberScrollState())
            .statusBarsPadding()
    ) {
        // 顶部栏
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButtonLike(onClick = { if (!vm.isProcessing) onExit() }) {
                Icon(Icons.Default.ArrowBack, contentDescription = "返回", tint = AcColor.Title)
            }
            Text(
                if (resultUrl == null) "框选视频水印" else "处理完成",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = AcColor.Title,
                modifier = Modifier.weight(1f)
            )
        }

        Text(
            if (resultUrl == null) "在视频画面上按住拖出方框，框住水印位置；点方框可删除"
            else "预览效果满意后保存到相册",
            fontSize = 13.sp,
            color = AcColor.Secondary,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
        )

        Spacer(Modifier.height(12.dp))

        // 视频 + 框选层
        Box(
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .width(displayWidth)
                .height(displayHeight)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black)
        ) {
            if (resultUrl == null && videoSize.height > 0f) {
                AndroidView(
                    factory = { ctx ->
                        VideoView(ctx).apply {
                            setVideoURI(Uri.fromFile(file.file))
                            setOnPreparedListener { mp ->
                                mp.isLooping = true
                                mp.setVolume(0f, 0f)
                                start()
                            }
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }

            if (resultUrl == null) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerInput(displayWidth, displayHeight) {
                            detectTapGestures { offset ->
                                val index = boxes.indexOfFirst { it.contains(offset) }
                                if (index >= 0) boxes.removeAt(index)
                            }
                        }
                        .pointerInput(displayWidth, displayHeight) {
                            detectDragGestures(
                                onDragStart = { offset ->
                                    dragStart = offset
                                    drawing = Rect(offset, Size.Zero)
                                },
                                onDrag = { change, _ ->
                                    change.consume()
                                    val start = dragStart ?: return@detectDragGestures
                                    drawing = rectOf(start, change.position)
                                },
                                onDragEnd = {
                                    val rect = drawing
                                    if (rect != null && rect.width > 12f && rect.height > 12f) {
                                        boxes.add(rect)
                                    }
                                    drawing = null
                                    dragStart = null
                                },
                                onDragCancel = {
                                    drawing = null
                                    dragStart = null
                                }
                            )
                        }
                ) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        boxes.forEach { rect ->
                            drawRect(
                                color = AcColor.TabActive.copy(alpha = 0.22f),
                                topLeft = rect.topLeft,
                                size = rect.size
                            )
                            drawRect(
                                color = AcColor.TabActive,
                                topLeft = rect.topLeft,
                                size = rect.size,
                                style = Stroke(width = 3f)
                            )
                        }
                        drawing?.let { rect ->
                            drawRect(
                                color = AcColor.TabActive.copy(alpha = 0.12f),
                                topLeft = rect.topLeft,
                                size = rect.size
                            )
                            drawRect(
                                color = AcColor.TabActive,
                                topLeft = rect.topLeft,
                                size = rect.size,
                                style = Stroke(width = 2f)
                            )
                        }
                    }
                }
            } else {
                AsyncVideoResult(url = resultUrl!!)
            }
        }

        Spacer(Modifier.height(16.dp))

        if (vm.isProcessing) {
            Column(Modifier.padding(horizontal = 20.dp)) {
                LinearProgressIndicator(
                    progress = { vm.progress / 100f },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                )
                Spacer(Modifier.height(6.dp))
                Text(vm.stageText, fontSize = 12.sp, color = AcColor.Secondary)
            }
        }

        if (resultUrl == null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = {
                        boxes.clear()
                        drawing = null
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(12.dp),
                    enabled = !vm.isProcessing
                ) { Text("撤销全部框选", fontSize = 13.sp) }

                Button(
                    onClick = {
                        if (videoSize.width <= 0f || videoSize.height <= 0f) {
                            vm.showToast("视频信息读取失败，请返回重新选择")
                            return@Button
                        }
                        if (boxes.isEmpty()) {
                            vm.showToast("请先在视频画面上框出至少一个水印区域")
                            return@Button
                        }
                        // 屏幕坐标 → 原视频像素坐标
                        val pxWidth = with(density) { displayWidth.toPx() }
                        val scale = if (pxWidth > 0f) videoSize.width / pxWidth else 1f
                        val json = boxes.joinToString(prefix = "[", postfix = "]") { r ->
                            val x = (r.left * scale).toInt().coerceAtLeast(0)
                            val y = (r.top * scale).toInt().coerceAtLeast(0)
                            val w = (r.width * scale).toInt().coerceAtLeast(1)
                            val h = (r.height * scale).toInt().coerceAtLeast(1)
                            """{"x":$x,"y":$y,"width":$w,"height":$h}"""
                        }
                        vm.processVideoRegions(json) { ok ->
                            if (ok) resultUrl = vm.results.lastOrNull()?.remoteUrl
                        }
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(12.dp),
                    enabled = !vm.isProcessing
                ) {
                    if (vm.isProcessing) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .width(18.dp)
                                .height(18.dp),
                            strokeWidth = 2.dp,
                            color = Color.White
                        )
                    } else {
                        Text("确认去除", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White)
            ) {
                Text(
                    "框选不满意？登录 AllClear 官网可以在电脑上做更精准的批量框选。",
                    fontSize = 12.sp,
                    color = AcColor.Secondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp)
                )
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = {
                        resultUrl = null
                        boxes.clear()
                        drawing = null
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(12.dp)
                ) { Text("重新框选", fontSize = 13.sp) }

                Button(
                    onClick = {
                        val url = resultUrl ?: return@Button
                        if (isSaving) return@Button
                        scope.launch {
                            isSaving = true
                            val outcome = runCatching {
                                withContext(Dispatchers.IO) {
                                    val name = withSuffix(file.name)
                                    val local = MediaSaver.download(context, url, name)
                                    MediaSaver.saveToGallery(context, local, true)
                                }
                            }
                            isSaving = false
                            outcome.onSuccess { vm.showToast("已保存到相册") }
                                .onFailure { vm.showToast(it.message ?: "保存失败") }
                        }
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isSaving
                ) {
                    if (isSaving) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .width(18.dp)
                                .height(18.dp),
                            strokeWidth = 2.dp,
                            color = Color.White
                        )
                    } else {
                        Text("保存到相册", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            OutlinedButton(
                onClick = { onExit() },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp)
                    .height(44.dp),
                shape = RoundedCornerShape(12.dp)
            ) { Text("返回首页", fontSize = 13.sp) }
        }

        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun IconButtonLike(onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .width(44.dp)
            .height(44.dp)
            .clip(RoundedCornerShape(12.dp))
            .pointerInput(Unit) { detectTapGestures { onClick() } },
        contentAlignment = Alignment.Center
    ) { content() }
}

/** 结果视频直接播放预览 */
@Composable
private fun AsyncVideoResult(url: String) {
    AndroidView(
        factory = { ctx ->
            VideoView(ctx).apply {
                setVideoURI(Uri.parse(url))
                setOnPreparedListener { mp ->
                    mp.isLooping = true
                    start()
                }
            }
        },
        modifier = Modifier.fillMaxSize()
    )
}

private fun rectOf(a: Offset, b: Offset): Rect = Rect(
    left = minOf(a.x, b.x),
    top = minOf(a.y, b.y),
    right = maxOf(a.x, b.x),
    bottom = maxOf(a.y, b.y)
)

/** 读取视频显示尺寸，已按旋转角交换宽高 */
private fun readDisplaySize(file: File): Size {
    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(file.absolutePath)
        val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloatOrNull() ?: 0f
        val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloatOrNull() ?: 0f
        val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        if (rotation == 90 || rotation == 270) Size(h, w) else Size(w, h)
    } catch (e: Exception) {
        Size.Zero
    } finally {
        runCatching { retriever.release() }
    }
}

private fun withSuffix(original: String): String {
    val dot = original.lastIndexOf('.')
    return if (dot in 1 until original.length - 1) {
        original.substring(0, dot) + "(无水印)" + original.substring(dot)
    } else {
        original + "(无水印)"
    }
}
