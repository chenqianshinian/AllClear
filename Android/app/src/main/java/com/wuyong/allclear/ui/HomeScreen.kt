package com.wuyong.allclear.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.wuyong.allclear.data.MediaSaver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun HomeScreen(vm: MainViewModel) {
    val context = LocalContext.current
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia()
    ) { uris: List<Uri> -> if (uris.isNotEmpty()) vm.addImages(uris) }

    val videoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? -> uri?.let { vm.setVideoUri(it) } }

    val docPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris: List<Uri> -> if (uris.isNotEmpty()) vm.addDocuments(uris) }

    // useAi / docPrompt 放在 ViewModel 里，切 Tab 回来不会丢

    // 保存全部结果：Android 10+ 走 MediaStore 无需权限，Android 9 及以下需写存储权限
    val saveAll: () -> Unit = {
        scope.launch {
            vm.showToast("正在保存…")
            val saved = runCatching {
                withContext(Dispatchers.IO) {
                    var galleryCount = 0
                    var downloadCount = 0
                    vm.results.forEach { result ->
                        val targetName = processedName(result.name)
                        val file = MediaSaver.download(context, result.remoteUrl, targetName)
                        if (result.isImage || result.isVideo) {
                            MediaSaver.saveToGallery(context, file, result.isVideo)
                            galleryCount++
                        } else {
                            MediaSaver.saveToDownloads(context, file)
                            downloadCount++
                        }
                    }
                    when {
                        galleryCount > 0 && downloadCount > 0 ->
                            "已保存：$galleryCount 个到相册，$downloadCount 个到下载目录"
                        galleryCount > 0 -> "已保存 $galleryCount 个文件到相册"
                        else -> "已保存 $downloadCount 个文件到下载目录"
                    }
                }
            }
            saved.onSuccess { vm.showToast(it) }
                .onFailure { vm.showToast(it.message ?: "保存失败") }
        }
    }

    val storagePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) saveAll() else vm.showToast("未授予存储权限，无法保存到相册")
    }

    val requestSaveAll: () -> Unit = {
        val needsPermission = Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        if (needsPermission) {
            storagePermissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        } else {
            saveAll()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scroll)
    ) {
        BlueHeader(
            title = "水印天敌",
            subtitle = "一键无痕去除图片 / 视频 / 文档水印"
        )

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .offset(y = (-28).dp),
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(18.dp)) {
                ModeTabs(current = vm.mode, onSelect = { vm.switchMode(it) })
                Spacer(Modifier.height(16.dp))
                SelectionBox(vm)

                Spacer(Modifier.height(18.dp))

                if (vm.mode == 0) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedButton(
                            onClick = {
                                imagePicker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                )
                            },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Image, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("传图片")
                        }
                        OutlinedButton(
                            onClick = {
                                videoPicker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
                                )
                            },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Movie, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("传视频")
                        }
                    }

                    val imageCount = vm.images.size
                    if (imageCount > 0 && vm.video == null) {
                        Spacer(Modifier.height(12.dp))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(AcColor.LightGray, RoundedCornerShape(10.dp))
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text("启用 AI 超强去水印", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Title)
                                Text("每张消耗 5 次额度，效果更佳", fontSize = 11.sp, color = AcColor.Secondary)
                            }
                            Switch(checked = vm.useAi, onCheckedChange = { vm.useAi = it })
                        }
                    }
                } else {
                    Button(
                        onClick = {
                            docPicker.launch(arrayOf("application/pdf", "application/msword",
                                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                "application/vnd.ms-powerpoint",
                                "application/vnd.openxmlformats-officedocument.presentationml.presentation"))
                        },
                        modifier = Modifier.fillMaxWidth().height(46.dp),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Description, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("选择文档（PDF / Word / PPT）")
                    }

                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = vm.docPrompt,
                        onValueChange = { vm.docPrompt = it },
                        label = { Text("水印文字（可选，用于强力擦除）") },
                        placeholder = { Text("例如：绝密资料") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )
                }

                Spacer(Modifier.height(16.dp))

                Button(
                    onClick = { vm.process(useAi = vm.useAi, prompt = vm.docPrompt.trim()) },
                    enabled = !vm.isProcessing && vm.currentFiles().isNotEmpty(),
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    if (vm.isProcessing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp,
                            color = Color.White
                        )
                        Spacer(Modifier.width(10.dp))
                        Text("处理中…")
                    } else {
                        Text(if (vm.currentFiles().isEmpty()) "请先选择文件" else "✨ 立即去除水印", fontWeight = FontWeight.Bold)
                    }
                }

                if (vm.isProcessing) {
                    Spacer(Modifier.height(12.dp))
                    LinearProgressIndicator(
                        progress = { vm.progress / 100f },
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(4.dp))
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(vm.stageText, fontSize = 12.sp, color = AcColor.Secondary)
                }

                if (vm.isLogin) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "剩余可用次数：${vm.points} 次",
                        fontSize = 12.sp,
                        color = AcColor.Secondary,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }

        if (vm.results.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            ResultSection(
                results = vm.results,
                onSaveAll = requestSaveAll,
                onShare = { result ->
                    scope.launch {
                        vm.showToast("正在准备分享…")
                        runCatching {
                            withContext(Dispatchers.IO) {
                                val targetName = processedName(result.name)
                                val file = MediaSaver.download(context, result.remoteUrl, targetName)
                                val uri = androidx.core.content.FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    file
                                )
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = when {
                                        result.isVideo -> "video/mp4"
                                        result.isImage -> "image/*"
                                        else -> "*/*"
                                    }
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(Intent.createChooser(intent, "分享处理结果"))
                            }
                        }.onFailure { vm.showToast(it.message ?: "分享失败") }
                    }
                },
                onClear = { vm.clearResult() }
            )
        }

        // 与鸿蒙端一致：文档处理结果不满意时，可输入水印文字再擦除一次
        if (vm.mode == 1 && vm.results.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF7ED))
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text(
                        "处理结果不满意？",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF9A3412)
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "如果部分顽固水印未能自动去除，输入水印文字可以再擦除一次（每次消耗 1 次额度）",
                        fontSize = 12.sp,
                        color = Color(0xFFC2410C),
                        lineHeight = 18.sp
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = vm.docPrompt,
                            onValueChange = { vm.docPrompt = it },
                            placeholder = { Text("例如：绝密资料") },
                            singleLine = true,
                            modifier = Modifier.weight(1f)
                        )
                        Spacer(Modifier.width(10.dp))
                        Button(
                            onClick = { vm.process(prompt = vm.docPrompt.trim()) },
                            enabled = !vm.isProcessing && vm.docPrompt.isNotBlank(),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text("重试")
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ModeTabs(current: Int, onSelect: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(AcColor.LightGray, RoundedCornerShape(10.dp))
            .padding(4.dp)
    ) {
        listOf("图片与视频", "PDF与文档").forEachIndexed { index, label ->
            val selected = current == index
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (selected) Color.White else Color.Transparent)
                    .clickable { onSelect(index) }
                    .padding(vertical = 9.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    label,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                    color = if (selected) AcColor.Primary else AcColor.Body
                )
            }
        }
    }
}

@Composable
private fun SelectionBox(vm: MainViewModel) {
    val files = vm.currentFiles()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp)
            .border(1.dp, Color(0xFFE2E5EA), RoundedCornerShape(14.dp))
            .background(Color(0xFFFAFBFC), RoundedCornerShape(14.dp)),
        contentAlignment = Alignment.Center
    ) {
        if (files.isEmpty()) {
            EmptyHint(
                text = if (vm.mode == 0) {
                    "请在下方选择图片或视频\n最多 ${vm.maxSelectCount} 个，图片 ≤ ${vm.maxImageMb.toInt()}MB，视频 ≤ ${vm.maxVideoMb.toInt()}MB"
                } else {
                    "请在下方选择 PDF / Word / PPT\n最多 ${vm.maxSelectCount} 个，单个 ≤ ${vm.maxDocumentMb.toInt()}MB"
                },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            Column(Modifier.fillMaxSize().padding(10.dp)) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(files) { item ->
                        Box(
                            modifier = Modifier
                                .size(112.dp)
                                .clip(RoundedCornerShape(10.dp))
                        ) {
                            when {
                                item.isImage -> AsyncImage(
                                    model = item.file,
                                    contentDescription = item.name,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize().background(Color(0xFFF0F2F5))
                                )
                                item.isVideo -> Box(
                                    Modifier.fillMaxSize().background(Color(0xFF1B1D21)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.Movie, contentDescription = null, tint = Color.White)
                                }
                                else -> Box(
                                    Modifier.fillMaxSize().background(AcColor.CardBg),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Icon(Icons.Default.Description, contentDescription = null, tint = AcColor.Primary)
                                        Spacer(Modifier.height(6.dp))
                                        Text(
                                            item.name,
                                            fontSize = 10.sp,
                                            maxLines = 2,
                                            overflow = TextOverflow.Ellipsis,
                                            color = AcColor.Body,
                                            modifier = Modifier.padding(horizontal = 6.dp)
                                        )
                                    }
                                }
                            }
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(4.dp)
                                    .size(20.dp)
                                    .background(Color(0x88000000), RoundedCornerShape(10.dp))
                                    .clickable {
                                        when {
                                            item.isVideo -> vm.removeVideo()
                                            item.kind == FileKind.DOCUMENT -> vm.removeDocument(item)
                                            else -> vm.removeImage(item)
                                        }
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Close, contentDescription = "移除", tint = Color.White, modifier = Modifier.size(13.dp))
                            }
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
                Text(
                    "已选择 ${files.size} 个文件",
                    fontSize = 12.sp,
                    color = AcColor.Body,
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .background(Color(0x14000000), RoundedCornerShape(20.dp))
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun ResultSection(
    results: List<ResultFile>,
    onSaveAll: () -> Unit,
    onShare: (ResultFile) -> Unit,
    onClear: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                if (results.size > 1) "处理结果（${results.size}）" else "处理结果",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = AcColor.Title
            )
            Spacer(Modifier.height(12.dp))

            if (results.size == 1) {
                ResultPreview(results.first())
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(onClick = onSaveAll, modifier = Modifier.weight(1f), shape = RoundedCornerShape(12.dp)) {
                        Text(if (results.first().isImage || results.first().isVideo) "保存到相册" else "保存到本地")
                    }
                    OutlinedButton(
                        onClick = { onShare(results.first()) },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("用其他应用打开")
                    }
                }
            } else {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(results) { item ->
                        Column(
                            modifier = Modifier.width(140.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(140.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(AcColor.LightGray),
                                contentAlignment = Alignment.Center
                            ) {
                                if (item.isImage) {
                                    AsyncImage(
                                        model = item.remoteUrl,
                                        contentDescription = item.name,
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                } else {
                                    Icon(
                                        if (item.isVideo) Icons.Default.Movie else Icons.Default.Description,
                                        contentDescription = null,
                                        tint = AcColor.Primary,
                                        modifier = Modifier.size(32.dp)
                                    )
                                }
                            }
                            Spacer(Modifier.height(6.dp))
                            Text(
                                item.name,
                                fontSize = 11.sp,
                                color = AcColor.Body,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.fillMaxWidth(),
                                textAlign = TextAlign.Center
                            )
                            TextButton(onClick = { onShare(item) }) {
                                Text("打开/分享", fontSize = 11.sp)
                            }
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
                Button(onClick = onSaveAll, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                    Text("💾 保存全部到相册 / 本地")
                }
            }

            Spacer(Modifier.height(8.dp))
            TextButton(onClick = onClear, modifier = Modifier.fillMaxWidth()) {
                Text("清空并继续处理", color = AcColor.Secondary)
            }
        }
    }
}

@Composable
private fun ResultPreview(result: ResultFile) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp, max = 320.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AcColor.LightGray),
        contentAlignment = Alignment.Center
    ) {
        if (result.isImage) {
            AsyncImage(
                model = result.remoteUrl,
                contentDescription = "处理结果",
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxWidth()
            )
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    if (result.isVideo) Icons.Default.Movie else Icons.Default.Description,
                    contentDescription = null,
                    tint = AcColor.Primary,
                    modifier = Modifier.size(36.dp)
                )
                Spacer(Modifier.height(8.dp))
                Text(result.name, fontSize = 13.sp, color = AcColor.Body, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(4.dp))
                Text("已生成，可保存或分享", fontSize = 12.sp, color = AcColor.Secondary)
            }
        }
    }
}

/** 结果文件名：原文件名 + (无水印) */
private fun processedName(original: String): String {
    val dot = original.lastIndexOf('.')
    return if (dot > 0 && dot < original.length - 1) {
        original.substring(0, dot) + "(无水印)" + original.substring(dot)
    } else {
        original + "(无水印)"
    }
}
