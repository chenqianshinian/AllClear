import Foundation

struct WatermarkRegion: Codable, Identifiable {
    let id = UUID()
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
}

struct LoginResponse: Decodable {
    let accessToken: String
}

/// 用户信息。字段对齐后端 /api/users/me（注意：后端用 tier 表示会员，不是 is_vip）
struct UserInfo: Codable {
    var id: Int = 0
    var nickname: String = ""
    var avatarUrl: String = ""
    var points: Int = 0          // 剩余去水印次数（后端字段 balance）
    var referralCode: String = ""
    var tier: String = "free"    // free / pro_monthly / pro_yearly
    var tierExpiresAtRaw: String?
    var checkinStreak: Int = 0
    var totalCheckins: Int = 0

    var isVip: Bool {
        guard tier == "pro_monthly" || tier == "pro_yearly" else { return false }
        guard let raw = tierExpiresAtRaw else { return true }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return true }
        return date > Date()
    }
}

/// /api/users/me 原始返回
struct UserMeResponse: Decodable {
    let id: Int
    let nickname: String?
    let avatarUrl: String?
    let balance: Int
    let tier: String?
    let tierExpiresAt: String?
    let referralCode: String?
    let checkinStreak: Int?
    let totalCheckins: Int?
}

/// /api/checkin 返回
struct CheckinResponse: Decodable {
    let message: String
    let balance: Int
    let streak: Int
    let totalCheckins: Int
}

/// /api/remove-watermark-batch 单项结果
struct BatchFileResult: Decodable {
    let filename: String
    let status: String
    let resultUrl: String?
    let reason: String?
}

/// /api/remove-watermark-batch 返回
struct BatchResponse: Decodable {
    let status: String
    let results: [BatchFileResult]
    let remainingPoints: Int?
}

/// 单文件接口（PDF / DOCX / PPTX）返回
struct SingleRemoveResponse: Decodable {
    let resultUrl: String
}
