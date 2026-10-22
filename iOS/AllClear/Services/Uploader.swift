import Foundation

/// multipart/form-data 上传。
/// 与鸿蒙端 Taro.uploadFile 保持一致：字段名、文件大小、Authorization 头都相同。
enum Uploader {
    struct Field {
        let name: String
        let value: String

        init(_ name: String, _ value: String) {
            self.name = name
            self.value = value
        }
    }

    struct FilePart {
        let name: String
        let filename: String
        let contentType: String
        private let source: Source

        private enum Source {
            case data(Data)
            case file(URL)
        }

        init(name: String, filename: String, data: Data, contentType: String) {
            self.name = name
            self.filename = filename
            self.contentType = contentType
            self.source = .data(data)
        }

        init(name: String, filename: String, fileURL: URL, contentType: String) {
            self.name = name
            self.filename = filename
            self.contentType = contentType
            self.source = .file(fileURL)
        }

        fileprivate func writeBody(to handle: FileHandle) throws {
            switch source {
            case .data(let data):
                try handle.write(contentsOf: data)
            case .file(let url):
                let input = try FileHandle(forReadingFrom: url)
                defer { try? input.close() }
                while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                    try handle.write(contentsOf: chunk)
                }
            }
        }
    }

    /// 先把 multipart 体写到临时文件，再用 uploadTask 携带进度上传，避免大视频占满内存。
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
        // 视频/文档是服务端同步处理，大文件可能耗时数分钟；与 Android 端保持一致设为 10 分钟
        request.timeoutInterval = 600

        do {
            let delegate = ProgressDelegate(onProgress: onProgress)
            let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL, delegate: delegate)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.emptyResponse
            }
            guard http.statusCode == 200 || http.statusCode == 201 else {
                throw APIError.from(status: http.statusCode, data: data)
            }
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private static func makeBodyFile(boundary: String, fields: [Field], files: [FilePart]) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "upload_\(UUID().uuidString).multipart")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw APIError.transport("无法创建上传缓存文件")
        }
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
            write("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(escape(filename: file.filename))\"\r\n")
            write("Content-Type: \(file.contentType)\r\n\r\n")
            try file.writeBody(to: handle)
            write("\r\n")
        }
        write("--\(boundary)--\r\n")
        return url
    }

    private static func escape(filename: String) -> String {
        filename.replacingOccurrences(of: "\"", with: "%22")
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
