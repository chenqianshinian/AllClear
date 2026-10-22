package com.wuyong.allclear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 首次启动隐私合规弹窗：未同意前不进入主界面。
 * 符合应用市场对“用户协议 / 隐私政策”强制确认的要求。
 */
@Composable
fun PrivacyConsentDialog(
    onAgree: () -> Unit,
    onExit: () -> Unit
) {
    var detail by remember { mutableStateOf<LegalType?>(null) }
    var checked by remember { mutableStateOf(false) }

    androidx.compose.ui.window.Dialog(
        onDismissRequest = { },
        properties = androidx.compose.ui.window.DialogProperties(
            dismissOnBackPress = false,
            dismissOnClickOutside = false
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(22.dp)
        ) {
            Text(
                "隐私保护提示",
                fontSize = 19.sp,
                fontWeight = FontWeight.Bold,
                color = AcColor.Title,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(14.dp))
            Text(
                "感谢使用 AllClear-水印天敌。在使用前，请阅读并同意以下条款：",
                fontSize = 13.sp,
                color = AcColor.Body,
                lineHeight = 21.sp
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "• 我们采用“阅后即焚”机制，不上传留存您的任何文件；\n" +
                    "• 仅收集邮箱账号与处理次数等必要信息；\n" +
                    "• 相册权限仅用于您主动选择素材与保存结果。",
                fontSize = 12.sp,
                color = AcColor.Body,
                lineHeight = 20.sp
            )
            Spacer(Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = checked, onCheckedChange = { checked = it })
                Text("我已阅读并同意", fontSize = 12.sp, color = AcColor.Body)
            }
            Row {
                Spacer(Modifier.width(40.dp))
                Text(
                    "《用户协议》",
                    fontSize = 12.sp,
                    color = AcColor.Primary,
                    modifier = Modifier.clickable { detail = LegalType.AGREEMENT }
                )
                Text("和", fontSize = 12.sp, color = AcColor.Body)
                Text(
                    "《隐私政策》",
                    fontSize = 12.sp,
                    color = AcColor.Primary,
                    modifier = Modifier.clickable { detail = LegalType.PRIVACY }
                )
            }
            Spacer(Modifier.height(18.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(
                    onClick = onExit,
                    modifier = Modifier.weight(1f).height(44.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("不同意并退出", fontSize = 12.sp, color = AcColor.Secondary)
                }
                Button(
                    onClick = { if (checked) onAgree() },
                    enabled = checked,
                    modifier = Modifier.weight(1f).height(44.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("同意并继续", fontSize = 13.sp)
                }
            }
        }
    }

    detail?.let { LegalDialog(type = it, onDismiss = { detail = null }) }
}
