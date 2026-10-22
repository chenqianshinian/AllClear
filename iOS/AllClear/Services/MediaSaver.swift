import Foundation
import Photos

/// 结果文件下载 + 保存到相册（对应鸿蒙版 downloadFileToSandbox + 保存相册）
enum MediaSaver {
    /// 下载远端结果到本地临时目录
    static func download(_ remote: URL, fallbackExtension: String) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: remote)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "文件下载失败")
        }
        var name = remote.lastPathComponent.removingPercentEncoding ?? remote.lastPathComponent
        if name.isEmpty || !name.contains(".") {
            name = "allclear_\(UUID().uuidString)\(fallbackExtension)"
        }
        let dest = URL.temporaryDirectory.appending(path: name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    /// 保存到系统相册
    static func saveToAlbum(_ fileURL: URL, isVideo: Bool) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "AllClear", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "未获得相册写入权限，请在系统设置中开启"])
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(with: isVideo ? .video : .photo, fileURL: fileURL, options: options)
        }
    }
}
