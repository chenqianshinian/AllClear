package com.wuyong.allclear.ui

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.foundation.Image
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.wuyong.allclear.data.ApiClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private data class PackageItem(
    val id: String,
    val title: String,
    val desc: String,
    val price: String,
    val tag: String? = null
)

private val packages = listOf(
    PackageItem("pack_10", "急救包", "包含 10 次处理额度", "¥ 4.90"),
    PackageItem("pro_monthly", "月卡会员", "30 天内包含 200 次额度", "¥ 19.90", "推荐"),
    PackageItem("pro_yearly", "专业会员", "365 天包含 3000 次额度", "¥ 99.00")
)

@Composable
fun RechargeDialog(vm: MainViewModel, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // 与鸿蒙端一致：已经是会员时只展示「急救包」，不再重复售卖会员档位
    val availablePackages = remember(vm.isVip) {
        if (vm.isVip) packages.filter { it.id == "pack_10" } else packages
    }
    var selected by remember(availablePackages) {
        mutableIntStateOf(if (availablePackages.size > 1) 1 else 0)
    }
    var method by remember { mutableStateOf("alipay") }
    var order by remember { mutableStateOf<ApiClient.Order?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }

    // 轮询订单状态
    LaunchedEffect(order?.orderId) {
        val id = order?.orderId ?: return@LaunchedEffect
        repeat(100) {
            delay(3000)
            val status = runCatching { withContext(Dispatchers.IO) { ApiClient.orderStatus(id) } }.getOrNull()
            if (status == "paid") {
                vm.showToast("充值成功！会员特权已生效")
                vm.refreshUser()
                order = null
                onDismiss()
                return@LaunchedEffect
            }
        }
    }

    Dialog(onDismissRequest = { if (!loading) onDismiss() }) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 620.dp)
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(20.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("升级专业会员", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AcColor.Title)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDismiss) { Text("关闭", color = AcColor.Secondary) }
            }
            Text("解锁大文件与批量处理特权", fontSize = 12.sp, color = AcColor.Secondary)
            Spacer(Modifier.height(14.dp))

            Column(
                modifier = Modifier
                    .weight(1f, fill = false)
                    .verticalScroll(rememberScrollState())
            ) {
                availablePackages.forEachIndexed { index, pkg ->
                    val isSelected = index == selected
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                if (isSelected) AcColor.CardBg else Color.White,
                                RoundedCornerShape(12.dp)
                            )
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(pkg.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Title)
                                if (pkg.tag != null) {
                                    Spacer(Modifier.width(6.dp))
                                    Text(
                                        pkg.tag,
                                        fontSize = 10.sp,
                                        color = Color.White,
                                        modifier = Modifier
                                            .background(AcColor.Primary, RoundedCornerShape(8.dp))
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                            Text(pkg.desc, fontSize = 12.sp, color = AcColor.Secondary)
                        }
                        Text(pkg.price, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Primary)
                        Spacer(Modifier.width(10.dp))
                        RadioButton(selected = isSelected, onClick = { if (!loading) selected = index })
                    }
                    Spacer(Modifier.height(10.dp))
                }

                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FilterChip(
                        selected = method == "alipay",
                        onClick = { if (!loading) { method = "alipay"; error = ""; order = null } },
                        label = { Text("支付宝") }
                    )
                    FilterChip(
                        selected = method == "wechat",
                        onClick = { if (!loading) { method = "wechat"; error = ""; order = null } },
                        label = { Text("微信支付") }
                    )
                }
            }

            if (error.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(error, color = Color(0xFFD93025), fontSize = 12.sp)
            }

            Spacer(Modifier.height(12.dp))

            if (order == null) {
                Button(
                    onClick = {
                        loading = true
                        error = ""
                        scope.launch {
                            val result = runCatching {
                                withContext(Dispatchers.IO) {
                                    ApiClient.createOrder(availablePackages[selected].id, method)
                                }
                            }
                            loading = false
                            result.onSuccess { order = it }
                                .onFailure { error = it.message ?: "创建订单失败，请重试" }
                        }
                    },
                    enabled = !loading,
                    modifier = Modifier.fillMaxWidth().height(46.dp),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    if (loading) {
                        CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color.White)
                    } else {
                        Text("确认支付 ${availablePackages[selected].price}")
                    }
                }
            } else {
                val payUrl = order?.payUrl.orEmpty()
                Text(
                    "请使用${if (method == "wechat") "微信" else "支付宝"}扫码支付 ¥${"%.2f".format(order?.amount ?: 0.0)}",
                    fontSize = 13.sp,
                    color = AcColor.Body,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(10.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    contentAlignment = Alignment.Center
                ) {
                    val bitmap = remember(payUrl) { generateQr(payUrl) }
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "支付二维码",
                            modifier = Modifier.size(180.dp)
                        )
                    } else {
                        Text("暂无二维码，可点击下方按钮打开支付页面", fontSize = 12.sp, color = AcColor.Secondary)
                    }
                }
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = {
                        if (payUrl.isBlank()) {
                            vm.showToast("暂未获取到支付链接，请稍后重试")
                        } else {
                            runCatching {
                                context.startActivity(
                                    Intent(Intent.ACTION_VIEW, Uri.parse(payUrl))
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                            }.onFailure { vm.showToast("无法打开支付页面，请改用扫码支付") }
                        }
                    },
                    modifier = Modifier.fillMaxWidth().height(44.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(if (method == "wechat") "打开微信支付" else "打开支付宝支付")
                }
                Text(
                    "支付成功后会自动到账，请稍候…",
                    fontSize = 11.sp,
                    color = AcColor.Secondary,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

private fun generateQr(content: String): Bitmap? {
    if (content.isBlank()) return null
    return runCatching {
        val size = 512
        val hints = mapOf(EncodeHintType.MARGIN to 1)
        val matrix = QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, size, size, hints)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        for (x in 0 until size) {
            for (y in 0 until size) {
                bitmap.setPixel(x, y, if (matrix[x, y]) 0xFF000000.toInt() else 0xFFFFFFFF.toInt())
            }
        }
        bitmap
    }.getOrNull()
}

@Composable
fun TutorialDialog(onDismiss: () -> Unit) {
    val steps = listOf(
        "第一步：登录" to "在“我的”页面登录账号，获取免费去水印次数。",
        "第二步：选择功能" to "根据需要选择“图片与视频”或“PDF与文档”选项卡。",
        "第三步：选择文件" to "点击对应按钮，从系统相册或文件管理中选择需要处理的素材。",
        "第四步：立即去除" to "点击亮起的“立即去除水印”按钮，等待云端处理完成。",
        "第五步：预览与保存" to "处理完成后可直接预览，满意则保存到相册或分享给其他应用。"
    )
    var index by remember { mutableIntStateOf(0) }

    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("快速上手指南", fontSize = 19.sp, fontWeight = FontWeight.Bold, color = AcColor.Title)
            Spacer(Modifier.height(16.dp))
            Text("${index + 1}", fontSize = 46.sp, fontWeight = FontWeight.Black, color = AcColor.TabActiveBg)
            Text(steps[index].first, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Title)
            Spacer(Modifier.height(10.dp))
            Text(
                steps[index].second,
                fontSize = 13.sp,
                color = AcColor.Body,
                textAlign = TextAlign.Center,
                lineHeight = 21.sp,
                modifier = Modifier.heightIn(min = 72.dp)
            )
            if (index == 2) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AcColor.CardBg, RoundedCornerShape(10.dp))
                        .padding(12.dp)
                ) {
                    Text("💡 小贴士", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Primary)
                    Text("图片与文档支持批量处理；视频因需准确定位水印，暂支持单个处理。", fontSize = 11.sp, color = AcColor.Body)
                }
                Spacer(Modifier.height(12.dp))
            }
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                TextButton(onClick = { if (index == 0) onDismiss() else index-- }) {
                    Text(if (index == 0) "跳过教程" else "上一步", color = AcColor.Secondary)
                }
                Button(onClick = {
                    if (index == steps.lastIndex) onDismiss() else index++
                }, shape = RoundedCornerShape(20.dp)) {
                    Text(if (index == steps.lastIndex) "立即体验" else "下一步")
                }
            }
        }
    }
}
