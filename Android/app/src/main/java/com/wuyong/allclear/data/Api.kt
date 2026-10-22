package com.wuyong.allclear.data

import com.wuyong.allclear.BuildConfig

/**
 * 与后端保持一致的接口地址与业务常量。
 * 默认：https://allclearwatermark.com/api
 * 本地联调：gradle :app:assembleDebug -PapiBase=http://10.0.2.2:8000/api
 */
object Api {
    const val BASE = BuildConfig.API_BASE
    const val ROOT = "https://allclearwatermark.com"

    const val LOGIN = "$BASE/login"
    const val REGISTER = "$BASE/register"
    const val USERS_ME = "$BASE/users/me"
    const val CHECKIN = "$BASE/checkin"
    const val SYSTEM_CONFIG = "$BASE/system/config"
    const val REMOVE_IMAGE = "$BASE/remove-image-watermark"
    const val REMOVE_VIDEO = "$BASE/remove-video-watermark"
    const val REMOVE_PDF = "$BASE/remove-pdf-watermark"
    const val REMOVE_DOCX = "$BASE/remove-docx-watermark"
    const val REMOVE_PPTX = "$BASE/remove-pptx-watermark"
    const val BATCH = "$BASE/remove-watermark-batch"
    const val ORDER_CREATE = "$BASE/orders/create"
    const val ORDER_STATUS = "$BASE/orders/status"
    const val AVATAR = "$BASE/users/avatar"

    /** 后端可能返回 /static/xxx 相对路径 */
    fun absolute(url: String): String = when {
        url.startsWith("http") -> url
        url.startsWith("/api/static") -> ROOT + url
        url.startsWith("/static") -> BASE + url
        url.startsWith("/") -> ROOT + url
        else -> url
    }

    const val SUPPORT_WECHAT = "chenqianshinian"
}
