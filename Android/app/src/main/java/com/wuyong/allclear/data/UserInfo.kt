package com.wuyong.allclear.data

import org.json.JSONObject

data class UserInfo(
    val id: Int = 0,
    val email: String = "",
    val nickname: String = "",
    val avatarUrl: String = "",
    val points: Int = 0,
    val referralCode: String = "",
    val tier: String = "free",
    val checkinStreak: Int = 0,
    val totalCheckins: Int = 0
) {
    val isVip: Boolean get() = tier == "pro_monthly" || tier == "pro_yearly"
    val displayName: String get() = nickname.ifBlank { email.substringBefore('@').ifBlank { "用户" } }

    fun toJson(): String = JSONObject().apply {
        put("id", id)
        put("email", email)
        put("nickname", nickname)
        put("avatarUrl", avatarUrl)
        put("points", points)
        put("referralCode", referralCode)
        put("tier", tier)
        put("checkinStreak", checkinStreak)
        put("totalCheckins", totalCheckins)
    }.toString()

    companion object {
        private fun JSONObject.text(key: String): String =
            if (isNull(key)) "" else optString(key).takeIf { it != "null" }.orEmpty()

        fun fromJson(raw: String): UserInfo? = runCatching {
            val o = JSONObject(raw)
            UserInfo(
                id = o.optInt("id"),
                email = o.text("email"),
                nickname = o.text("nickname").ifBlank { o.text("nickName") },
                avatarUrl = o.text("avatar_url").ifBlank { o.text("avatarUrl") },
                points = o.optInt("balance"),
                referralCode = o.text("referral_code").ifBlank { o.text("referralCode") },
                tier = o.text("tier").ifBlank { "free" },
                checkinStreak = o.optInt("checkin_streak"),
                totalCheckins = o.optInt("total_checkins")
            )
        }.getOrNull()
    }
}
