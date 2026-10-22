import Foundation

/// multipart/form-data 上传（对应鸿蒙版 HttpUtil.uploadFile / uploadBatchFiles）
/// 说明：统一带 client=miniprogram 字段，让后端直接返回 JSON。
enum Uploader {
    struct Field {
        let name: String
        let value: String
    }

    struct FilePart {
        let name: String
        let filename: String
        let data: Data
        let contentType: String
    }

    /// 边写边传：先把 multipart 体写到临时文件，再用 uploadTask 携带进度上传
    static func upload(
        to url: URL,
        token: String?,
        fields: [Field],
        files: [FilePart],
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        let bodyURL = try makeBodyFile(boundary: boundary, fields: fields, files: files)
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 120

        let delegate = ProgressDelegate(onProgress: onProgress)
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL, delegate: delegate)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.emptyResponse
        }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw APIError.server(status: http.statusCode, message: message)
        }
        return data
    }

    private static func makeBodyFile(boundary: String, fields: [Field], files: [FilePart]) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "upload_\(UUID().uuidString).multipart")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        func write(_ text: String) {
            if let data = text.data(using: .utf8) { try? handle.write(contentsOf: data) }
        }

        for field in fields {
            write("--\(boundary)\r\n")
            write("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            write("\(field.value)\r\n")
        }
        for file in files {
            write("--\(boundary)\r\n")
            write("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            write("Content-Type: \(file.contentType)\r\n\r\n")
            try handle.write(contentsOf: file.data)
            write("\r\n")
        }
        write("--\(boundary)--\r\n")
        return url
    }
}

/// 上传进度回调（URLSessionTaskDelegate 是 AnyObject，用 final class 桥接）
private final class ProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let onProgress: (@MainActor (Double) -> Void)?

    init(onProgress: (@MainActor (Double) -> Void)?) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0, let onProgress else { return }
        let percent = Double(totalBytesSent) / Double(totalBytesExpectedToSend) * 100
        Task { @MainActor in onProgress(percent) }
    }
}
