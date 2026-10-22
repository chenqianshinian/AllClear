package com.wuyong.allclear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog

@Composable
fun LoginDialog(
    vm: MainViewModel,
    onDismiss: () -> Unit,
    onSuccess: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isRegister by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }

    Dialog(onDismissRequest = { if (!loading) onDismiss() }) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                if (isRegister) "注册账号" else "登录账号",
                fontSize = 19.sp,
                fontWeight = FontWeight.Bold,
                color = AcColor.Title
            )
            Spacer(Modifier.height(18.dp))
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("邮箱") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("密码") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth()
            )
            if (error.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(error, color = Color(0xFFD93025), fontSize = 12.sp)
            }
            Spacer(Modifier.height(18.dp))
            Button(
                onClick = {
                    if (email.isBlank() || password.isBlank()) {
                        error = "请输入邮箱和密码"
                        return@Button
                    }
                    if (!email.contains('@')) {
                        error = "请输入正确的邮箱地址"
                        return@Button
                    }
                    loading = true
                    error = ""
                    if (isRegister) {
                        vm.register(email, password) { ok, message ->
                            loading = false
                            if (ok) {
                                isRegister = false
                                vm.showToast(message)
                            } else {
                                error = message
                            }
                        }
                    } else {
                        vm.login(email, password) { ok, message ->
                            loading = false
                            if (ok) {
                                vm.showToast(message)
                                onSuccess()
                            } else {
                                error = message
                            }
                        }
                    }
                },
                enabled = !loading,
                modifier = Modifier.fillMaxWidth().height(46.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                if (loading) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color.White)
                } else {
                    Text(if (isRegister) "注 册" else "登 录")
                }
            }
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton(onClick = { if (!loading) onDismiss() }) {
                    Text("取消", color = AcColor.Secondary)
                }
                TextButton(onClick = { isRegister = !isRegister; error = "" }) {
                    Text(if (isRegister) "已有账号？去登录" else "没有账号？去注册", color = AcColor.Primary)
                }
            }
        }
    }
}

@Composable
fun SupportDialog(onDismiss: () -> Unit, onCopy: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("联系客服", fontSize = 19.sp, fontWeight = FontWeight.Bold, color = AcColor.Title)
            Spacer(Modifier.height(12.dp))
            Text(
                "如有任何问题或建议，欢迎添加专属客服微信进行反馈交流。",
                fontSize = 13.sp,
                color = AcColor.Body,
                lineHeight = 20.sp
            )
            Spacer(Modifier.height(16.dp))
            Row {
                Text("客服微信：", fontSize = 14.sp, color = AcColor.Body)
                Text("chenqianshinian", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AcColor.Primary)
            }
            Spacer(Modifier.height(20.dp))
            Button(onClick = onCopy, modifier = Modifier.fillMaxWidth().height(44.dp), shape = RoundedCornerShape(12.dp)) {
                Text("📋 一键复制微信号")
            }
            TextButton(onClick = onDismiss) {
                Text("暂不需要", color = AcColor.Secondary)
            }
        }
    }
}

enum class LegalType(val title: String) {
    AGREEMENT("用户协议"),
    PRIVACY("隐私政策")
}

@Composable
fun DeleteAccountDialog(
    onDismiss: () -> Unit,
    onConfirm: ((Boolean, String) -> Unit) -> Unit
) {
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }

    Dialog(onDismissRequest = { if (!loading) onDismiss() }) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("注销账号", fontSize = 19.sp, fontWeight = FontWeight.Bold, color = AcColor.Title)
            Spacer(Modifier.height(12.dp))
            Text(
                "注销后，您的账号、剩余次数、会员权益及处理记录将被永久删除且无法恢复，已购买的额度不予退还。",
                fontSize = 13.sp,
                color = AcColor.Body,
                lineHeight = 20.sp
            )
            if (error.isNotBlank()) {
                Spacer(Modifier.height(10.dp))
                Text(error, color = Color(0xFFD93025), fontSize = 12.sp)
            }
            Spacer(Modifier.height(20.dp))
            Button(
                onClick = {
                    loading = true
                    error = ""
                    onConfirm { ok, message ->
                        loading = false
                        if (!ok) error = message
                    }
                },
                enabled = !loading,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE54D4F)),
                modifier = Modifier.fillMaxWidth().height(44.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                if (loading) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = Color.White)
                } else {
                    Text("确认注销")
                }
            }
            TextButton(onClick = onDismiss, enabled = !loading) {
                Text("暂不注销", color = AcColor.Secondary)
            }
        }
    }
}

@Composable
fun LegalDialog(type: LegalType, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 560.dp)
                .background(Color.White, RoundedCornerShape(18.dp))
                .padding(20.dp)
        ) {
            Text(type.title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AcColor.Title)
            Spacer(Modifier.height(12.dp))
            Column(
                Modifier
                    .weight(1f, fill = false)
                    .verticalScroll(rememberScrollState())
            ) {
                val sections = if (type == LegalType.AGREEMENT) agreementSections else privacySections
                sections.forEach { (heading, body) ->
                    if (heading.isNotBlank()) {
                        Text(
                            heading,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = AcColor.Title,
                            modifier = Modifier.padding(top = 10.dp, bottom = 6.dp)
                        )
                    }
                    Text(body, fontSize = 13.sp, color = AcColor.Body, lineHeight = 21.sp)
                }
            }
            Spacer(Modifier.height(12.dp))
            Button(onClick = onDismiss, modifier = Modifier.fillMaxWidth().height(42.dp), shape = RoundedCornerShape(12.dp)) {
                Text("我知道了")
            }
        }
    }
}

private val agreementSections: List<Pair<String, String>> = listOf(
    "" to "欢迎使用 AllClear——水印天敌（以下简称“本服务”）。在使用本服务前，请您务必仔细阅读并透彻理解本协议。一旦您使用本服务，即表示您已阅读、理解并同意接受本协议的所有条款。",
    "1. 服务说明" to "本服务主要提供针对图片、视频、PDF、Word 及 PPT 等文件的 AI 水印去除功能。我们致力于提供高质量的处理结果，但受限于技术客观条件，我们无法保证 100% 的完美去除效果。",
    "2. 阅后即焚与文件处理机制" to "本平台秉持最高级别的数据安全原则，采用“阅后即焚”机制。您上传的所有原文件以及处理后的文件仅在系统内存或临时目录中进行瞬时处理。一旦处理完成并由您下载（或处理失败、超时），相关文件将立即被永久销毁，我们绝不保存、备份或滥用您的任何文件。",
    "3. 知识产权与免责声明" to "• 您承诺，您上传至本平台进行处理的文件，您均拥有合法的著作权或已获得版权人的充分授权。\n• 您不得使用本服务去除他人享有版权的作品上的保护性水印，并用于商业牟利、侵权传播等非法用途。\n• 免责声明：本平台仅提供中立的技术处理工具。因您使用本服务处理文件所引发的任何版权纠纷、法律诉讼及经济赔偿，均由您自行承担，本平台不承担任何直接或间接的法律责任。",
    "4. 账号与服务变更" to "本平台有权根据业务发展需要，随时调整免费处理次数、计费规则、订阅价格及产品功能。如有重大变更，我们将通过系统公告或界面提示的方式告知用户。"
)

private val privacySections: List<Pair<String, String>> = listOf(
    "" to "AllClear——水印天敌 非常重视您的隐私保护。本《隐私政策》旨在向您说明我们在提供服务时收集、使用、存储及保护您个人信息的方式。",
    "1. 极简的数据收集声明" to "为了向您提供基础的账号注册、登录及去水印额度追踪服务，我们仅收集以下极其有限的必要信息：\n• 账号标识：您注册时提供的邮箱地址、手机号码或第三方授权标识。\n• 操作日志：仅记录您处理文件的类型（如视频、图片）及文件大小，用于扣减您的可用处理次数和宏观业务统计。",
    "2. 文件的“零保留”承诺" to "我们承诺，您上传用于去水印的图片、视频、文档等一切媒体文件，均遵循“阅后即焚”原则。系统仅在内存及安全沙盒内完成自动化处理，完成后原文件和结果文件将被系统自动彻底删除。我们不会将其用于模型训练、数据分析或任何其他商业用途。",
    "3. 设备权限调用说明" to "为提供核心业务功能，我们可能需要您授权以下设备权限：\n• 存储 / 相册权限：仅用于您在 App 内主动选择需要去水印的图片、视频或文档，以及保存处理后的文件到本地设备。我们绝不会在后台秘密读取您的相册内容。\n• 网络访问权限：用于上传待处理文件及下载处理完成的文件。",
    "4. 账号注销与数据删除" to "您拥有完全的账号控制权。登录后可在“我的 - 注销账号”中直接提交注销，也可通过“我的 - 联系客服”申请。账号注销后，我们将立即删除您的账号、剩余次数、会员权益及历史处理记录，且无法恢复。",
    "5. 第三方 SDK 说明" to "为保障应用基础功能正常运行，本应用使用以下第三方组件：\n• OkHttp（网络请求）：用于上传待处理文件、下载处理结果及访问账号接口，不收集个人信息。\n• Coil（图片加载）：仅用于在应用内显示您选择的图片及处理结果。\n• ZXing（二维码生成）：在本地生成支付二维码，不访问网络。\n除上述组件外，本应用未集成统计、广告或推送类 SDK。",
    "6. 开发者主体信息" to "本应用由 马鞍山市雨山区悟用网络科技工作室（个体工商户）开发并运营。如有隐私相关疑问，请通过客服渠道联系我们。"
)
