package com.wuyong.allclear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import com.wuyong.allclear.data.ApiClient
import com.wuyong.allclear.ui.AcColor
import com.wuyong.allclear.ui.HomeScreen
import com.wuyong.allclear.ui.MainViewModel
import com.wuyong.allclear.ui.MineScreen
import com.wuyong.allclear.ui.PrivacyConsentDialog
import com.wuyong.allclear.ui.ToastHost
import com.wuyong.allclear.ui.VideoEditScreen

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ApiClient.init(applicationContext)
        enableEdgeToEdge()
        setContent {
            MaterialTheme(
                colorScheme = lightColorScheme(
                    primary = AcColor.Primary,
                    secondary = AcColor.TabActive,
                    background = Color.White,
                    surface = Color.White
                )
            ) {
                AllClearApp()
            }
        }
    }
}

private enum class Tab { REMOVE, MINE }

@Composable
private fun AllClearApp() {
    val vm: MainViewModel = viewModel()
    val context = androidx.compose.ui.platform.LocalContext.current
    var tab by remember { mutableStateOf(Tab.REMOVE) }
    var agreed by remember { mutableStateOf(vm.hasAgreedPrivacy()) }

    LaunchedEffect(Unit) { vm.refreshUser() }

    // 与鸿蒙端 useDidShow 一致：每次回到前台都刷新一次账号额度
    LifecycleResumeEffect(Unit) {
        vm.refreshUser()
        vm.loadSystemConfig()
        onPauseOrDispose { }
    }

    if (!agreed) {
        PrivacyConsentDialog(
            onAgree = {
                vm.setAgreedPrivacy()
                agreed = true
            },
            onExit = { (context as? android.app.Activity)?.finish() }
        )
        return
    }

    // 选完视频后进入框选页（与鸿蒙端 pages/video-edit 一致）
    val editing = vm.editingVideo
    if (editing != null) {
        VideoEditScreen(vm = vm, file = editing, onExit = { vm.closeVideoEditor() })
        ToastHost(vm)
        return
    }

    Scaffold(
        containerColor = AcColor.PageBg,
        bottomBar = {
            NavigationBar(containerColor = Color.White, tonalElevation = 0.dp) {
                NavigationBarItem(
                    selected = tab == Tab.REMOVE,
                    onClick = {
                        if (vm.isProcessing) vm.showToast("正在处理，请稍候…") else tab = Tab.REMOVE
                    },
                    icon = { Icon(Icons.Default.AutoFixHigh, contentDescription = null) },
                    label = { Text("去水印") }
                )
                NavigationBarItem(
                    selected = tab == Tab.MINE,
                    onClick = {
                        if (vm.isProcessing) vm.showToast("正在处理，请稍候…") else tab = Tab.MINE
                    },
                    icon = { Icon(Icons.Default.Person, contentDescription = null) },
                    label = { Text("我的") }
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(AcColor.PageBg)
        ) {
            when (tab) {
                Tab.REMOVE -> HomeScreen(vm)
                Tab.MINE -> MineScreen(vm, onNavigateRemove = { tab = Tab.REMOVE })
            }
        }
    }

    ToastHost(vm)
}
