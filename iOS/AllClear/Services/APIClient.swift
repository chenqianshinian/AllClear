import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case notLoggedIn
    case server(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "接口地址无效"
        case .notLoggedIn: return "请先登录"
        case .server(let status, let message): return "服务错误(\(status)): \(message)"
        case .emptyResponse: return "服务返回为空"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: "https://allclearwatermark.com/api")!
    var authToken: String? {
        didSet { UserDefaults.standard.set(authToken, forKey: "auth_token") }
    }

    private init() {
        authToken = UserDefaults.standard.string(forKey: "auth_token")
    }

    private func authorizedRequest(_ path: String) throws -> URLRequest {
        guard let token = authToken else { throw APIError.notLoggedIn }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    private func errorMessage(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = obj["detail"] as? String {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? "未知错误"
    }

    func login(username: String, password: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "username=\(username)&password=\(password)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                  message: errorMessage(from: data))
        }
        let token = try decode(data, as: LoginResponse.self).accessToken
        authToken = token
    }

    /// GET /users/me —— 刷新用户信息（次数 / 会员等级）
    func usersMe() async throws -> UserMeResponse {
        var request = try authorizedRequest("users/me")
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                  message: errorMessage(from: data))
        }
        return try decode(data, as: UserMeResponse.self)
    }

    /// POST /checkin —— 每日签到领次数
    func checkin() async throws -> CheckinResponse {
        let data = try await postJSON("checkin", body: [:])
        return try decode(data, as: CheckinResponse.self)
    }

    /// POST /orders/apple-iap —— 把 StoreKit 交易凭证交给后端验签发货
    /// 注：后端需新增该接口（对应鸿蒙版的 /orders/huawei-iap）
    func verifyApplePurchase(productId: String, signedTransaction: String) async throws {
        let data = try await postJSON("orders/apple-iap", body: [
            "product_id": productId,
            "signed_transaction": signedTransaction
        ])
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = obj["status"] as? String, status != "success" {
            throw APIError.server(status: -1, message: (obj["message"] as? String) ?? "发货失败，请联系客服")
        }
    }

    private func postJSON(_ path: String, body: [String: Any]) async throws -> Data {
        var request = try authorizedRequest(path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 201 else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                  message: errorMessage(from: data))
        }
        return data
    }

    // MARK: - 去水印

    /// 图片 / 视频批量接口：一次传一个文件（与鸿蒙版一致，避免同名覆盖）
    func removeWatermarkBatch(
        fileData: Data,
        filename: String,
        fileType: String,
        regions: String? = nil,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> BatchResponse {
        var fields = [
            Uploader.Field(name: "file_type", value: fileType),
            Uploader.Field(name: "client", value: "miniprogram")
        ]
        if let authToken {
            fields.append(Uploader.Field(name: "token", value: authToken))
        }
        if let regions {
            fields.append(Uploader.Field(name: "regions", value: regions))
        }
        let data = try await Uploader.upload(
            to: baseURL.appendingPathComponent("remove-watermark-batch"),
            token: authToken,
            fields: fields,
            files: [Uploader.FilePart(name: "files", filename: filename, data: fileData, contentType: "application/octet-stream")],
            onProgress: onProgress
        )
        return try decode(data, as: BatchResponse.self)
    }

    /// 文档接口：按后缀路由到 pdf / docx / pptx
    func removeDocument(
        endpoint: String,
        fileData: Data,
        filename: String,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> String {
        var fields = [
            Uploader.Field(name: "file_type", value: "document"),
            Uploader.Field(name: "client", value: "miniprogram")
        ]
        if let authToken {
            fields.append(Uploader.Field(name: "token", value: authToken))
        }
        let data = try await Uploader.upload(
            to: baseURL.appendingPathComponent(endpoint),
            token: authToken,
            fields: fields,
            files: [Uploader.FilePart(name: "file", filename: filename, data: fileData, contentType: "application/octet-stream")],
            onProgress: onProgress
        )
        return try decode(data, as: SingleRemoveResponse.self).resultUrl
    }

    /// 结果文件的完整地址（后端可能返回 /static/xxx 相对路径）
    func absoluteResultURL(_ raw: String) -> URL? {
        if raw.hasPrefix("http") { return URL(string: raw) }
        if raw.hasPrefix("/static") { return URL(string: "https://allclearwatermark.com/api" + raw) }
        return URL(string: "https://allclearwatermark.com" + raw)
    }
}

