package com.wuyong.allclear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/** 全局轻量提示（替代系统 Toast，跨页面可用） */
@Composable
fun ToastHost(vm: MainViewModel) {
    val message = vm.toast
    LaunchedEffect(message) {
        if (message != null) {
            delay(2200)
            vm.consumeToast()
        }
    }
    if (message == null) return
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
        Text(
            text = message.text,
            color = Color.White,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(bottom = 96.dp, start = 32.dp, end = 32.dp)
                .background(Color(0xE6323232), RoundedCornerShape(10.dp))
                .padding(horizontal = 16.dp, vertical = 10.dp)
        )
    }
}
