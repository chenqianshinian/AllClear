import Foundation
import Photos

/// 结果文件下载 + 保存到相册（对应鸿蒙端 downloadFile + saveImageToPhotosAlbum）
enum MediaSaver {
    /// 下载远端结果到本地临时目录；也可以传入本地 URL 做一次“改名拷贝”。
    @discardableResult
    static func download(
        _ remote: URL,
        suggestedName: String? = nil,
        fallbackExtension: String = ".jpg"
    ) async throws -> URL {
        let fileName = sanitize(suggestedName ?? defaultFileName(remote, fallbackExtension: fallbackExtension))
        let directory = URL.temporaryDirectory.appending(path: "allclear_\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: fileName)

        if remote.isFileURL {
            if remote.standardizedFileURL == destination.standardizedFileURL { return destination }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: remote, to: destination)
            return destination
        }

        var request = URLRequest(url: remote)
        request.timeoutInterval = 300
        do {
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "文件下载失败")
            }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tempURL, to: destination)
            return destination
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    /// 保存图片 / 视频到系统相册
    static func saveToAlbum(_ fileURL: URL, isVideo: Bool) async throws {
        ACDebugLog.log("saveToAlbum start file=\(fileURL.lastPathComponent) video=\(isVideo) exists=\(FileManager.default.fileExists(atPath: fileURL.path))")
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        ACDebugLog.log("saveToAlbum auth status=\(status.rawValue)")
        guard status == .authorized || status == .limited else {
            ACDebugLog.log("saveToAlbum permission denied")
            throw NSError(domain: "AllClear", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "未获得相册写入权限，请在系统设置中开启"])
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: isVideo ? .video : .photo, fileURL: fileURL, options: options)
            }
            ACDebugLog.log("saveToAlbum performChanges done")
        } catch {
            ACDebugLog.log("saveToAlbum performChanges error=\(error)")
            throw error
        }
    }

    /// 文档下载后使用原文件名 + (无水印)，与鸿蒙端一致
    static func documentFileName(original: String) -> String {
        let ns = original as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        if ext.isEmpty { return "\(base)(无水印)" }
        return "\(base)(无水印).\(ext)"
    }

    private static func defaultFileName(_ url: URL, fallbackExtension: String) -> String {
        var name = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        if name.isEmpty { name = "allclear_\(UUID().uuidString)" }
        if !name.contains(".") { name += fallbackExtension }
        return name
    }

    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "_")
        return cleaned.isEmpty ? "allclear_\(UUID().uuidString)" : cleaned
    }
}
