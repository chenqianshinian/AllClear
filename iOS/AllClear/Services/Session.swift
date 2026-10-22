import Foundation

/// 全局登录态与用户信息（对应鸿蒙版 LoginManager）。
@MainActor
final class Session: ObservableObject {
    static let shared = Session()

    @Published private(set) var user: UserInfo?
    @Published private(set) var isLogin = false

    private let tokenKey = "auth_token"
    private let userKey = "user_info"

    private init() {
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            APIClient.shared.authToken = token
            isLogin = true
            if let data = UserDefaults.standard.data(forKey: userKey),
               let cached = try? JSONDecoder().decode(UserInfo.self, from: data) {
                user = cached
            }
        }
    }

    // MARK: - 派生状态（对应鸿蒙版 getMaxSelectNumber / 体积限制）
    var points: Int { user?.points ?? 0 }
    var isVip: Bool { user?.isVip ?? false }
    var maxSelectCount: Int { isVip ? 20 : 3 }
    var maxImageMB: Double { isVip ? 20 : 5 }
    var maxDocumentMB: Double { 30 }

    // MARK: - 动作
    func login(email: String, password: String) async throws {
        try await APIClient.shared.login(username: email, password: password)
        isLogin = true
        await refreshUserInfo()
    }

    func refreshUserInfo() async {
        guard isLogin else { return }
        do {
            let me = try await APIClient.shared.usersMe()
            user = UserInfo(
                id: me.id,
                nickname: me.nickname ?? "用户",
                avatarUrl: me.avatarUrl ?? "",
                points: me.balance,
                referralCode: me.referralCode ?? "",
                tier: me.tier ?? "free",
                tierExpiresAtRaw: me.tierExpiresAt,
                checkinStreak: me.checkinStreak ?? 0,
                totalCheckins: me.totalCheckins ?? 0
            )
            persist()
        } catch {
            // 刷新失败时保留本地缓存，不打断用户操作
        }
    }

    func updatePoints(_ points: Int) {
        user?.points = points
        persist()
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
