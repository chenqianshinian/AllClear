package com.wuyong.allclear.ui

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.wuyong.allclear.data.Api
import com.wuyong.allclear.data.UserInfo

@Composable
fun MineScreen(vm: MainViewModel, onNavigateRemove: () -> Unit) {
    val context = LocalContext.current
    val scroll = rememberScrollState()
    var showLogin by remember { mutableStateOf(false) }
    var showRecharge by remember { mutableStateOf(false) }
    var showTutorial by remember { mutableStateOf(false) }
    var showSupport by remember { mutableStateOf(false) }
    var legalType by remember { mutableStateOf<LegalType?>(null) }
    var agreed by remember { mutableStateOf(true) }
    var isCheckingIn by remember { mutableStateOf(false) }
    var showDeleteAccount by remember { mutableStateOf(false) }

    // 扫码登录电脑版
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        val raw = result.contents
        if (!raw.isNullOrBlank()) {
            val prefix = "allclear_login:"
            if (raw.startsWith(prefix)) {
                vm.confirmScanLogin(raw.removePrefix(prefix).trim()) { _, message -> vm.showToast(message) }
            } else {
                vm.showToast("无效的登录二维码")
            }
        }
    }

    val launchScanner: () -> Unit = {
        scanLauncher.launch(
            ScanOptions().apply {
                setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                setPrompt("将电脑端二维码放入框内")
                setBeepEnabled(false)
                setOrientationLocked(true)
            }
        )
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) launchScanner() else vm.showToast("需要相机权限才能扫码登录")
    }

    LaunchedEffect(Unit) {
        vm.refreshUser()
        vm.loadSystemConfig()
    }

    val versionName = remember(context) {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull().orEmpty()
    }

    Box(Modifier.fillMaxSize()) {
        // 顶部蓝色背景（先绘制，保证卡片在其上层）
        Box(
            Modifier
                .fillMaxWidth()
                .height(220.dp)
                .background(AcColor.Primary)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scroll)
        ) {
            Spacer(Modifier.height(120.dp))
            UserCard(
                vm = vm,
                agreed = agreed,
                onAgreedChange = { agreed = it },
                onLogin = { showLogin = true },
                onOpenLegal = { legalType = it },
                isCheckingIn = isCheckingIn,
                onCheckin = {
                    isCheckingIn = true
                    vm.checkin { ok, message ->
                        isCheckingIn = false
                        vm.showToast(
                            if (!ok && message.contains("今日已签到")) "今日已签到，请明天再来~" else message
                        )
                    }
                },
                onLogout = {
                    vm.logout()
                    vm.showToast("已退出登录")
                }
            )
            Spacer(Modifier.height(16.dp))
            MenuCard(
                isLogin = vm.isLogin,
                showRecharge = !vm.inReview,
                onTutorial = { showTutorial = true },
                onInvite = {
                    if (!vm.isLogin) {
                        vm.showToast("请先登录")
                        return@MenuCard
                    }
                    val code = vm.user?.referralCode.orEmpty()
                    val text = "一键免费批量去除图片、视频、文档水印，快来试试！ https://allclearwatermark.com?code=$code"
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    context.startActivity(Intent.createChooser(send, "邀请好友"))
                },
                onRecharge = {
                    if (!vm.isLogin) {
                        vm.showToast("请先登录")
                        return@MenuCard
                    }
                    showRecharge = true
                },
                onSupport = { showSupport = true },
                onDeleteAccount = { showDeleteAccount = true },
                onScanLogin = {
                    if (!vm.isLogin) {
                        vm.showToast("请先登录")
                        return@MenuCard
                    }
                    val granted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) launchScanner() else cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                }
            )
            Spacer(Modifier.height(20.dp))
            Text(
                "AllClear 水印天敌 v$versionName",
                fontSize = 11.sp,
                color = AcColor.Secondary,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(28.dp))
        }

        // 顶部标题
        Column(Modifier.padding(start = 20.dp, top = 44.dp)) {
            Text("我的", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text("账号与会员中心", color = Color(0xFFD8E4FF), fontSize = 12.sp)
        }
    }

    if (showLogin) {
        LoginDialog(
            vm = vm,
            onDismiss = { showLogin = false },
            onSuccess = { showLogin = false }
        )
    }
    if (showRecharge) {
        RechargeDialog(vm = vm, onDismiss = { showRecharge = false })
    }
    if (showTutorial) {
        TutorialDialog(onDismiss = { showTutorial = false })
    }
    if (showSupport) {
        SupportDialog(
            onDismiss = { showSupport = false },
            onCopy = {
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("wechat", Api.SUPPORT_WECHAT))
                vm.showToast("微信号已复制，请前往微信添加好友")
                showSupport = false
            }
        )
    }
    legalType?.let { type ->
        LegalDialog(type = type, onDismiss = { legalType = null })
    }
    if (showDeleteAccount) {
        DeleteAccountDialog(
            onDismiss = { showDeleteAccount = false },
            onConfirm = { done ->
                vm.deleteAccount { ok, message ->
                    if (ok) {
                        vm.showToast(message)
                        showDeleteAccount = false
                    }
                    done(ok, message)
                }
            }
        )
    }
}

@Composable
private fun UserCard(
    vm: MainViewModel,
    agreed: Boolean,
    onAgreedChange: (Boolean) -> Unit,
    onLogin: () -> Unit,
    onOpenLegal: (LegalType) -> Unit,
    isCheckingIn: Boolean,
    onCheckin: () -> Unit,
    onLogout: () -> Unit
) {
    val user = vm.user
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp)
            .background(Color.White, RoundedCornerShape(18.dp))
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(76.dp)
                .clip(CircleShape)
                .background(Color(0xFFEFF1F5)),
            contentAlignment = Alignment.Center
        ) {
            val avatar = user?.avatarUrl.orEmpty()
            if (vm.isLogin && avatar.isNotBlank()) {
                AsyncImage(
                    model = avatar,
                    contentDescription = "头像",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                Text("👤", fontSize = 34.sp)
            }
        }
        Spacer(Modifier.height(12.dp))

        if (vm.isLogin) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    user?.displayName ?: "用户",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AcColor.Title
                )
                if (user?.isVip == true) {
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "PRO",
                        fontSize = 10.sp,
                        color = Color(0xFFB26B00),
                        modifier = Modifier
                            .background(Color(0xFFFFF1D6), RoundedCornerShape(8.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text("剩余次数：", fontSize = 13.sp, color = AcColor.Body)
                Text("${vm.points}", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AcColor.Primary)
                Text(" 次", fontSize = 13.sp, color = AcColor.Body)
            }
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = onCheckin,
                    enabled = !isCheckingIn,
                    modifier = Modifier.weight(1f).height(42.dp),
                    shape = RoundedCornerShape(21.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFFFFF5E6),
                        contentColor = Color(0xFFF28C00)
                    )
                ) {
                    Text(if (isCheckingIn) "签到中…" else "📅 每日签到领次数", fontSize = 12.sp)
                }
                OutlinedButton(
                    onClick = onLogout,
                    modifier = Modifier.weight(1f).height(42.dp),
                    shape = RoundedCornerShape(21.dp)
                ) {
                    Text("退出登录", fontSize = 12.sp, color = Color(0xFFE54D4F))
                }
            }
        } else {
            Text("未登录", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Title)
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    if (!agreed) {
                        vm.showToast("请先阅读并同意用户协议和隐私政策")
                        return@Button
                    }
                    onLogin()
                },
                modifier = Modifier.fillMaxWidth().height(44.dp),
                shape = RoundedCornerShape(22.dp)
            ) {
                Text("邮箱登录 / 注册")
            }
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = agreed, onCheckedChange = onAgreedChange)
                Text("我已阅读并同意", fontSize = 11.sp, color = AcColor.Secondary)
                Text(
                    "《用户协议》",
                    fontSize = 11.sp,
                    color = AcColor.Primary,
                    modifier = Modifier.clickable { onOpenLegal(LegalType.AGREEMENT) }
                )
                Text("和", fontSize = 11.sp, color = AcColor.Secondary)
                Text(
                    "《隐私政策》",
                    fontSize = 11.sp,
                    color = AcColor.Primary,
                    modifier = Modifier.clickable { onOpenLegal(LegalType.PRIVACY) }
                )
            }
        }
    }
}

@Composable
private fun MenuCard(
    isLogin: Boolean,
    showRecharge: Boolean,
    onTutorial: () -> Unit,
    onInvite: () -> Unit,
    onRecharge: () -> Unit,
    onSupport: () -> Unit,
    onDeleteAccount: () -> Unit,
    onScanLogin: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp)
            .background(Color.White, RoundedCornerShape(18.dp))
    ) {
        MenuRow("📖", "操作教程", onTutorial)
        if (isLogin) {
            HorizontalDivider(color = AcColor.Separator, thickness = 1.dp, modifier = Modifier.padding(start = 18.dp))
            MenuRow("💻", "扫码登录电脑版", onScanLogin)
        }
        HorizontalDivider(color = AcColor.Separator, thickness = 1.dp, modifier = Modifier.padding(start = 18.dp))
        MenuRow("👥", "邀请好友 (送次数)", onInvite)
        if (showRecharge) {
            HorizontalDivider(color = AcColor.Separator, thickness = 1.dp, modifier = Modifier.padding(start = 18.dp))
            MenuRow("💎", "充值 / 升级会员", onRecharge)
        }
        HorizontalDivider(color = AcColor.Separator, thickness = 1.dp, modifier = Modifier.padding(start = 18.dp))
        MenuRow("📞", "联系客服", onSupport)
        if (isLogin) {
            HorizontalDivider(color = AcColor.Separator, thickness = 1.dp, modifier = Modifier.padding(start = 18.dp))
            MenuRow("🗑️", "注销账号", onDeleteAccount, danger = true)
        }
    }
}

@Composable
private fun MenuRow(
    icon: String,
    title: String,
    onClick: () -> Unit,
    danger: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, fontSize = 18.sp)
        Spacer(Modifier.width(10.dp))
        Text(
            title,
            fontSize = 15.sp,
            color = if (danger) Color(0xFFE54D4F) else AcColor.Title,
            modifier = Modifier.weight(1f)
        )
        Text("›", fontSize = 18.sp, color = Color(0xFFC8CDD5))
    }
}
