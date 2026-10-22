package com.wuyong.allclear.data

import android.content.Context
import okhttp3.FormBody
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

class ApiException(message: String, val status: Int = -1) : Exception(message)

/**
 * 轻量网络层：OkHttp + 手写 JSON，避免额外序列化依赖。
 * 所有鉴权接口统一走 Authorization: Bearer <token>。
 */
object ApiClient {

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        // 视频/大文档为同步处理，服务端可能耗时数分钟，读超时必须足够长
        .readTimeout(10, TimeUnit.MINUTES)
        .writeTimeout(10, TimeUnit.MINUTES)
        .build()

    private const val PREFS = "allclear_prefs"
    private const val KEY_TOKEN = "auth_token"
    private const val KEY_USER = "user_info"

    @Volatile
    var token: String? = null
        private set

    fun init(context: Context) {
        token = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TOKEN, null)
            ?.takeIf { it.isNotBlank() }
    }

    fun hasToken(): Boolean = !token.isNullOrBlank()

    private fun saveToken(context: Context, value: String?) {
        token = value
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            if (value.isNullOrBlank()) remove(KEY_TOKEN) else putString(KEY_TOKEN, value)
        }.apply()
    }

    fun saveCachedUser(context: Context, user: UserInfo?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            if (user == null) remove(KEY_USER) else putString(KEY_USER, user.toJson())
        }.apply()
    }

    fun cachedUser(context: Context): UserInfo? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_USER, null) ?: return null
        return UserInfo.fromJson(raw)
    }

    private fun errorMessage(body: String, code: Int): String {
        val detail = runCatching { JSONObject(body).optString("detail") }.getOrDefault("")
        return when {
            detail.isNotBlank() && detail != "null" -> detail
            code == 401 -> "登录已过期，请重新登录"
            code == 403 -> "次数不足，请前往“我的”页面充值或签到"
            code == 413 -> "文件过大，请压缩后重试"
            code == 402 -> "额度不足，请前往“我的”页面补充"
            else -> "请求失败（$code）"
        }
    }

    // ---------- 账号 ----------

    fun login(context: Context, email: String, password: String): UserInfo {
        val form = FormBody.Builder()
            .add("username", email)
            .add("password", password)
            .build()
        val request = Request.Builder().url(Api.LOGIN).post(form).build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(body, resp.code), resp.code)
            val access = JSONObject(body).optString("access_token")
            if (access.isBlank()) throw ApiException("登录失败，请检查账号密码")
            saveToken(context, access)
        }
        return me(context)
    }

    fun register(email: String, password: String) {
        val json = JSONObject().put("email", email).put("password", password).toString()
        val request = Request.Builder()
            .url(Api.REGISTER)
            .post(json.toRequestBody("application/json".toMediaType()))
            .build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(body, resp.code), resp.code)
        }
    }

    fun me(context: Context): UserInfo {
        val request = authorized(Api.USERS_ME).get().build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                if (resp.code == 401) logout(context)
                throw ApiException(errorMessage(body, resp.code), resp.code)
            }
            return UserInfo.fromJson(body) ?: throw ApiException("用户信息解析失败")
        }
    }

    fun checkin(): Pair<String, Int> {
        val request = authorized(Api.CHECKIN)
            .post("{}".toRequestBody("application/json".toMediaType()))
            .build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(body, resp.code), resp.code)
            val o = JSONObject(body)
            return o.optString("message", "签到成功") to o.optInt("balance")
        }
    }

    /** 审核模式：为 true 时隐藏充值入口；请求失败返回 null（保持调用方现有状态） */
    fun inReview(): Boolean? {
        val request = Request.Builder().url(Api.SYSTEM_CONFIG).get().build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) return null
            return runCatching { JSONObject(body).optBoolean("in_review") }.getOrNull()
        }
    }

    /** 账号注销 */
    fun deleteAccount(context: Context) {
        val request = authorized(Api.USERS_ME).delete().build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(body, resp.code), resp.code)
        }
        logout(context)
    }

    fun logout(context: Context) {
        saveToken(context, null)
        saveCachedUser(context, null)
    }

    // ---------- 去水印 ----------

    /** 图片 / 视频：单文件上传，返回可直接下载的结果地址 */
    fun removeMedia(
        file: File,
        isVideo: Boolean,
        useAi: Boolean = false,
        prompt: String? = null,
        onProgress: ((Int) -> Unit)? = null
    ): String {
        val url = if (isVideo) Api.REMOVE_VIDEO else Api.REMOVE_IMAGE
        val fileBody = FileProgressBody(file, "application/octet-stream".toMediaType(), onProgress)
        val builder = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", file.name, fileBody)
            .addFormDataPart("regions", "[]")
            .addFormDataPart("client", "miniprogram")
        if (!isVideo) {
            builder.addFormDataPart("use_ai", if (useAi) "true" else "false")
            if (!prompt.isNullOrBlank()) builder.addFormDataPart("prompt", prompt)
        }
        val request = authorized(url).post(builder.build()).build()
        client.newCall(request).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(text, resp.code), resp.code)
            val o = JSONObject(text)
            return Api.absolute(
                o.optString("result_url").ifBlank {
                    o.optString("output_url").ifBlank { o.optString("url") }
                }
            )
        }
    }

    /** PDF / Word / PPT */
    fun removeDocument(file: File, prompt: String = "", onProgress: ((Int) -> Unit)? = null): String {
        val name = file.name.lowercase()
        val url = when {
            name.endsWith(".pdf") -> Api.REMOVE_PDF
            name.endsWith(".doc") || name.endsWith(".docx") -> Api.REMOVE_DOCX
            name.endsWith(".ppt") || name.endsWith(".pptx") -> Api.REMOVE_PPTX
            else -> throw ApiException("不支持的文档格式")
        }
        val fileBody = FileProgressBody(file, "application/octet-stream".toMediaType(), onProgress)
        val multipart = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", file.name, fileBody)
            .addFormDataPart("prompt", prompt)
            .addFormDataPart("client", "miniprogram")
            .build()
        val request = authorized(url).post(multipart).build()
        client.newCall(request).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(text, resp.code), resp.code)
            return Api.absolute(JSONObject(text).optString("result_url"))
        }
    }

    // ---------- 充值 ----------

    data class Order(val orderId: String, val amount: Double, val payUrl: String, val status: String)

    fun createOrder(packageId: String, method: String): Order {
        val json = JSONObject()
            .put("package_id", packageId)
            .put("payment_method", method)
            .put("client", "web")
            .toString()
        val request = authorized(Api.ORDER_CREATE)
            .post(json.toRequestBody("application/json".toMediaType()))
            .build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(body, resp.code), resp.code)
            val o = JSONObject(body)
            return Order(
                orderId = o.optString("order_id"),
                amount = o.optDouble("amount", 0.0),
                payUrl = o.optString("pay_url"),
                status = o.optString("status")
            )
        }
    }

    fun orderStatus(orderId: String): String {
        val request = authorized("${Api.ORDER_STATUS}/$orderId").get().build()
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(errorMessage(body, resp.code), resp.code)
            return JSONObject(body).optString("status")
        }
    }

    private fun authorized(url: String): Request.Builder {
        val builder = Request.Builder().url(url)
        token?.let { builder.header("Authorization", "Bearer $it") }
        return builder
    }
}
