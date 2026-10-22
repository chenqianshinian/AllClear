import Foundation

/// 全局登录态与用户信息（对应鸿蒙端 LoginManager / Taro.getStorageSync('token')）。
@MainActor
final class Session: ObservableObject {
    static let shared = Session()

    @Published private(set) var user: UserInfo?
    @Published private(set) var isLogin = false
    /// 后端审核模式开关（/system/config in_review），与鸿蒙端一致
    @Published var inReview = false

    private let tokenKey = "auth_token"
    private let userKey = "user_info"

    private init() {
        let token = UserDefaults.standard.string(forKey: tokenKey)
        if let token, !token.isEmpty {
            APIClient.shared.authToken = token
            isLogin = true
            if let data = UserDefaults.standard.data(forKey: userKey),
               let cached = try? JSONDecoder().decode(UserInfo.self, from: data) {
                user = cached
            }
        }
    }

    // MARK: - 派生状态（与官网/鸿蒙端 H5 的额度规则保持一致）
    // 免费：单次 3 个 / 图片 5MB / 视频 10MB / 文档 10MB
    // 会员：单次 20 个 / 图片 20MB / 视频 50MB / 文档 50MB
    var points: Int { user?.points ?? 0 }
    var isVip: Bool { user?.isVip ?? false }
    var isPro: Bool { user?.isPro ?? false }
    var maxSelectCount: Int { isVip ? 20 : 3 }
    var maxImageMB: Double { isVip ? 20 : 5 }
    var maxVideoMB: Double { isVip ? 50 : 10 }
    var maxDocumentMB: Double { isVip ? 50 : 10 }

    // MARK: - 动作
    func login(email: String, password: String) async throws {
        try await APIClient.shared.login(username: email, password: password)
        isLogin = true
        if user == nil {
            user = UserInfo(email: email)
        }
        await refreshUserInfo()
    }

    func register(email: String, password: String) async throws {
        try await APIClient.shared.register(email: email, password: password)
    }

    func refreshUserInfo() async {
        guard isLogin else { return }
        do {
            let me = try await APIClient.shared.usersMe()
            let email = me.email ?? user?.email ?? ""
            let serverNickname = me.nickname ?? ""
            let fallbackName: String = {
                if !serverNickname.isEmpty { return serverNickname }
                if let prefix = email.split(separator: "@").first, !prefix.isEmpty { return String(prefix) }
                return "用户"
            }()
            user = UserInfo(
                id: me.id,
                email: email,
                nickname: fallbackName,
                avatarUrl: me.avatarUrl ?? "",
                points: me.balance,
                referralCode: me.referralCode ?? "",
                tier: me.tier ?? "free",
                tierExpiresAtRaw: me.tierExpiresAt,
                checkinStreak: me.checkinStreak ?? 0,
                totalCheckins: me.totalCheckins ?? 0
            )
            persist()
        } catch let error as APIError {
            if error.isUnauthorized {
                logout()
            }
            // 其它错误保留本地缓存，不打断用户操作
        } catch {
            // 网络错误保留本地缓存
        }
    }

    func refreshSystemConfig() async {
        do {
            let config = try await APIClient.shared.systemConfig()
            inReview = config.inReview
        } catch {
            // 配置读取失败时保持默认值，不阻塞页面
        }
    }

    func updatePoints(_ points: Int) {
        user?.points = points
        persist()
    }

    func updateNickname(_ nickname: String) {
        user?.nickname = nickname
        persist()
    }

    func updateAvatar(_ url: String) {
        user?.avatarUrl = url
        persist()
    }

    func checkin() async throws -> CheckinResponse {
        let result = try await APIClient.shared.checkin()
        updatePoints(result.balance)
        return result
    }

    /// 账号注销：服务端删除成功后立即清空本地登录态
    func deleteAccount() async throws {
        try await APIClient.shared.deleteAccount()
        logout()
    }

    func logout() {
        isLogin = false
        user = nil
        APIClient.shared.authToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    private func persist() {
        if let token = APIClient.shared.authToken {
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
        if let user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}
