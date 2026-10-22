import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case notLoggedIn
    case unauthorized
    case server(status: Int, message: String)
    case emptyResponse
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "接口地址无效"
        case .notLoggedIn:
            return "请先登录"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .server(_, let message):
            return message
        case .emptyResponse:
            return "服务返回为空"
        case .transport:
            return "网络异常或服务繁忙，请稍后再试"
        case .decoding:
            return "服务返回格式异常，请稍后再试"
        }
    }

    var statusCode: Int? {
        if case .server(let status, _) = self { return status }
        if case .unauthorized = self { return 401 }
        return nil
    }

    var isUnauthorized: Bool {
        statusCode == 401
    }

    /// 402 / 403 或文案中包含额度不足，用于 Toast 长停留
    var isQuotaError: Bool {
        if let status = statusCode, status == 402 || status == 403 { return true }
        let text = errorDescription ?? ""
        return text.contains("次数不足") || text.contains("额度不足")
    }

    static func from(status: Int, data: Data) -> APIError {
        if status == 401 { return .unauthorized }
        let detail = APIClient.extractDetail(from: data)
        let message = APIClient.translateDetail(detail) ?? "服务错误(\(status))"
        return .server(status: status, message: message)
    }
}

final class APIClient {
    static let shared = APIClient()

    static let host = "https://allclearwatermark.com"

    var baseURL: URL = URL(string: "https://allclearwatermark.com/api")!

    var authToken: String? {
        didSet {
            if let authToken, !authToken.isEmpty {
                UserDefaults.standard.set(authToken, forKey: "auth_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "auth_token")
            }
        }
    }

    private init() {
        authToken = UserDefaults.standard.string(forKey: "auth_token")
        // 调试可覆盖：simctl launch ... -apiBaseURL http://127.0.0.1:8000/api
        if let override = UserDefaults.standard.string(forKey: "api_base_url"), let url = URL(string: override) {
            baseURL = url
        }
    }

    // MARK: - 登录 / 注册 / 用户

    func login(username: String, password: String) async throws {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        let body = (components.percentEncodedQuery ?? "").data(using: .utf8)

        var request = URLRequest(url: baseURL.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw APIError.server(status: 401, message: "登录失败，请检查账号密码")
            }
            throw APIError.from(status: http.statusCode, data: data)
        }
        let token = try decode(data, as: LoginResponse.self).accessToken
        authToken = token
    }

    func register(email: String, password: String) async throws {
        // 注册接口不需要登录态（不能用 authorizedRequest）
        var request = URLRequest(url: baseURL.appendingPathComponent("register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password
        ])
        request.timeoutInterval = 30
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            throw APIError.from(status: http.statusCode, data: data)
        }
    }

    /// GET /users/me —— 刷新用户信息（次数 / 会员等级）
    func usersMe() async throws -> UserMeResponse {
        var request = try authorizedRequest("users/me")
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard http.statusCode == 200 else { throw APIError.from(status: http.statusCode, data: data) }
        return try decode(data, as: UserMeResponse.self)
    }

    /// 与鸿蒙端 PUT /users/me { nickName } 一致
    func updateNickname(_ nickname: String) async throws {
        _ = try await sendJSON("users/me", method: "PUT", body: ["nickName": nickname])
    }

    /// 与鸿蒙端 Taro.uploadFile('/users/avatar', name: 'file') 一致
    func uploadAvatar(data: Data, filename: String = "avatar.jpg") async throws -> String {
        guard let token = authToken else { throw APIError.notLoggedIn }
        let response = try await Uploader.upload(
            to: baseURL.appendingPathComponent("users/avatar"),
            token: token,
            fields: [],
            files: [Uploader.FilePart(name: "file", filename: filename, data: data, contentType: "image/jpeg")]
        )
        struct AvatarResponse: Decodable {
            let avatarUrl: String?
        }
        return try decode(response, as: AvatarResponse.self).avatarUrl ?? ""
    }

    /// GET /system/config —— in_review 审核模式开关
    func systemConfig() async throws -> SystemConfig {
        var request = URLRequest(url: baseURL.appendingPathComponent("system/config"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard http.statusCode == 200 else { throw APIError.from(status: http.statusCode, data: data) }
        return try decode(data, as: SystemConfig.self)
    }

    /// POST /checkin —— 每日签到领次数（保留能力，与后端一致）
    func checkin() async throws -> CheckinResponse {
        let data = try await postJSON("checkin", body: [:])
        return try decode(data, as: CheckinResponse.self)
    }

    /// 扫码登录电脑版确认（与鸿蒙端一致）
    func confirmScanLogin(sceneId: String) async throws {
        _ = try await sendJSON("auth/scan/confirm", method: "POST", body: ["scene_id": sceneId])
    }

    // MARK: - 去水印（对齐鸿蒙端单文件接口）

    /// POST /remove-image-watermark
    func removeImage(
        fileData: Data,
        filename: String,
        useAI: Bool,
        regions: String = "[]",
        prompt: String? = nil,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> URL {
        guard let token = authToken else { throw APIError.notLoggedIn }
        var fields: [Uploader.Field] = [
            Uploader.Field("regions", regions),
            Uploader.Field("use_ai", useAI ? "true" : "false"),
            Uploader.Field("client", "miniprogram")
        ]
        if let prompt, !prompt.isEmpty { fields.append(Uploader.Field("prompt", prompt)) }

        let data = try await Uploader.upload(
            to: baseURL.appendingPathComponent("remove-image-watermark"),
            token: token,
            fields: fields,
            files: [Uploader.FilePart(name: "file", filename: filename, data: fileData, contentType: "application/octet-stream")],
            onProgress: onProgress
        )
        return try resultURL(from: data)
    }

    /// POST /remove-video-watermark
    func removeVideo(
        fileURL: URL,
        filename: String,
        regions: [WatermarkRegion],
        prompt: String? = nil,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> URL {
        guard let token = authToken else { throw APIError.notLoggedIn }
        let regionsData = try JSONEncoder().encode(regions)
        let regionsString = String(data: regionsData, encoding: .utf8) ?? "[]"
        var fields: [Uploader.Field] = [
            Uploader.Field("regions", regionsString),
            Uploader.Field("client", "miniprogram")
        ]
        if let prompt, !prompt.isEmpty { fields.append(Uploader.Field("prompt", prompt)) }

        let data = try await Uploader.upload(
            to: baseURL.appendingPathComponent("remove-video-watermark"),
            token: token,
            fields: fields,
            files: [Uploader.FilePart(name: "file", filename: filename, fileURL: fileURL, contentType: "application/octet-stream")],
            onProgress: onProgress
        )
        return try resultURL(from: data)
    }

    /// 文档接口：按后缀路由到 pdf / docx / pptx
    func removeDocument(
        endpoint: String,
        fileData: Data,
        filename: String,
        prompt: String? = nil,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> URL {
        guard let token = authToken else { throw APIError.notLoggedIn }
        var fields: [Uploader.Field] = [Uploader.Field("client", "miniprogram")]
        if let prompt, !prompt.isEmpty { fields.append(Uploader.Field("prompt", prompt)) }

        let data = try await Uploader.upload(
            to: baseURL.appendingPathComponent(endpoint),
            token: token,
            fields: fields,
            files: [Uploader.FilePart(name: "file", filename: filename, data: fileData, contentType: "application/octet-stream")],
            onProgress: onProgress
        )
        return try resultURL(from: data)
    }

    /// StoreKit 交易凭证交给后端验签发货（后端预留 /orders/apple-iap）
    func verifyApplePurchase(productId: String, signedTransaction: String) async throws {
        let data = try await sendJSON("orders/apple-iap", method: "POST", body: [
            "product_id": productId,
            "signed_transaction": signedTransaction
        ])
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = obj["status"] as? String, status != "success" {
            throw APIError.server(status: -1, message: (obj["message"] as? String) ?? "发货失败，请联系客服")
        }
    }

    // MARK: - URL / 解码工具

    /// 结果文件的完整地址（后端可能返回 /static/xxx 相对路径）
    func absoluteResultURL(_ raw: String) -> URL? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return URL(string: value) }
        if value.hasPrefix("/static") { return URL(string: Self.host + "/api" + value) }
        if value.hasPrefix("/api/") { return URL(string: Self.host + value) }
        if value.hasPrefix("/") { return URL(string: Self.host + value) }
        return URL(string: Self.host + "/" + value)
    }

    private func resultURL(from data: Data) throws -> URL {
        let response = try decode(data, as: RemoveResultResponse.self)
        guard let raw = response.rawURL, let url = absoluteResultURL(raw) else {
            throw APIError.decoding("服务未返回处理结果")
        }
        return url
    }

    private func authorizedRequest(_ path: String) throws -> URLRequest {
        guard let token = authToken, !token.isEmpty else { throw APIError.notLoggedIn }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[APIClient] decode failed: \(error) body=\(String(data: data, encoding: .utf8) ?? "")")
            #endif
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func postJSON(_ path: String, body: [String: Any]) async throws -> Data {
        try await sendJSON(path, method: "POST", body: body)
    }

    private func sendJSON(_ path: String, method: String, body: [String: Any]) async throws -> Data {
        var request = try authorizedRequest(path)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            throw APIError.from(status: http.statusCode, data: data)
        }
        return data
    }

    // MARK: - 错误文案

    static func extractDetail(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let detail = obj["detail"] as? String { return detail }
        if let detail = obj["detail"] as? [[String: Any]] {
            let messages = detail.compactMap { $0["msg"] as? String }
            if !messages.isEmpty { return messages.joined(separator: "；") }
        }
        if let message = obj["message"] as? String { return message }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func translateDetail(_ detail: String?) -> String? {
        guard var detail, !detail.isEmpty else { return nil }
        let map: [String: String] = [
            "Incorrect email/account or password": "登录失败，请检查账号密码",
            "Email/Account already registered": "该邮箱已注册，请直接登录",
            "Could not validate credentials": "登录已过期，请重新登录",
            "Not Found": "服务接口不存在，请稍后再试",
            "Internal Server Error": "服务器繁忙，请稍后再试"
        ]
        for (key, value) in map where detail.contains(key) {
            detail = value
            break
        }
        return detail
    }
}
