package com.wuyong.allclear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 与 iOS / 鸿蒙一致的品牌配色 */
object AcColor {
    val Primary = Color(0xFF3072F6)
    val TabActive = Color(0xFF1296DB)
    val TabActiveBg = Color(0xFFE8F4FF)
    val Title = Color(0xFF333333)
    val Body = Color(0xFF666666)
    val Secondary = Color(0xFF999999)
    val LightGray = Color(0xFFF5F5F5)
    val CardBg = Color(0xFFF2F6FF)
    val Separator = Color(0xFFF0F0F0)
    val PageBg = Color(0xFFF7F8FA)
    val Warning = Color(0xFFE67817)
}

/** 顶部蓝色标题区（首页/我的共用） */
@Composable
fun BlueHeader(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(listOf(Color(0xFF3A79F7), Color(0xFF2E6AE8)))
            )
            .padding(start = 24.dp, end = 24.dp, top = 56.dp, bottom = 40.dp)
    ) {
        Column {
            Text(
                text = title,
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.ExtraBold
            )
            if (subtitle != null) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = subtitle,
                    color = Color(0xFFDBE7FF),
                    fontSize = 13.sp
                )
            }
        }
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier,
        color = AcColor.Title,
        fontSize = 17.sp,
        fontWeight = FontWeight.Bold
    )
}

@Composable
fun EmptyHint(text: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = AcColor.Secondary,
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
            lineHeight = 20.sp
        )
    }
}

/** 统一样式的圆角卡片 */
@Composable
fun CardBox(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .background(Color.White, RoundedCornerShape(18.dp))
            .padding(18.dp),
        content = content
    )
}
