import Foundation

// MARK: - 水印区域（对应鸿蒙端 regions 数组元素）
struct WatermarkRegion: Codable, Identifiable, Hashable {
    var id = UUID()
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
    }
}

// MARK: - 登录 / 用户

struct LoginResponse: Decodable {
    let accessToken: String
    let tokenType: String?
}

/// 用户信息。字段对齐后端 /api/users/me（后端用 tier 表示会员，balance 表示次数）
struct UserInfo: Codable {
    var id: Int = 0
    var email: String = ""
    var nickname: String = ""
    var avatarUrl: String = ""
    var points: Int = 0          // 剩余去水印次数（后端字段 balance）
    var referralCode: String = ""
    var tier: String = "free"    // free / pro_monthly / pro_yearly
    var tierExpiresAtRaw: String?
    var checkinStreak: Int = 0
    var totalCheckins: Int = 0

    var isPro: Bool { tier.contains("pro") }

    var isVip: Bool {
        guard isPro else { return false }
        guard let raw = tierExpiresAtRaw else { return true }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return true }
        return date > Date()
    }

    /// 鸿蒙端 nickname 为空时用邮箱前缀兜底
    var displayName: String {
        if !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nickname }
        if !email.isEmpty, let prefix = email.split(separator: "@").first, !prefix.isEmpty {
            return String(prefix)
        }
        return "用户"
    }
}

/// /api/users/me 原始返回
struct UserMeResponse: Decodable {
    let id: Int
    let email: String?
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

/// /api/system/config
struct SystemConfig: Decodable {
    let inReview: Bool
}

/// /api/orders/apple-iap 返回（后端预留）
struct AppleIAPResponse: Decodable {
    let status: String
    let message: String?
}

// MARK: - 去水印接口返回
// 后端在不同接口可能返回 result_url / output_url / url，这里统一兼容。
struct RemoveResultResponse: Decodable {
    let resultUrl: String?
    let outputUrl: String?
    let url: String?

    var rawURL: String? { resultUrl ?? outputUrl ?? url }
}

// MARK: - 页面状态

enum FileTab: String, CaseIterable, Hashable {
    case media
    case document

    var title: String {
        switch self {
        case .media: return "图片与视频"
        case .document: return "PDF与文档"
        }
    }
}

enum PickedKind: String, Hashable {
    case image
    case video
    case document
}

struct PickedFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let sizeMB: Double
    let kind: PickedKind
}

struct ResultFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let filename: String
    let kind: PickedKind

    var ext: String { url.pathExtension.lowercased() }
    var isImage: Bool { kind == .image }
    var isVideo: Bool { kind == .video }
    var isDocument: Bool { kind == .document }
}

enum ProcessStatus: String {
    case idle
    case processing
    case success
}

/// 视频框选页入参
struct VideoEditInput: Hashable {
    let url: URL
    let width: CGFloat
    let height: CGFloat

    var aspectRatio: CGFloat {
        guard height > 0 else { return 16.0 / 9.0 }
        return width / height
    }
}

/// 全局导航路由
enum AppRoute: Hashable {
    case videoEdit(VideoEditInput)
    case recharge
}
