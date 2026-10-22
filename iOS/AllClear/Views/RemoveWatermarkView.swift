import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 本地已选文件
struct PickedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let sizeMB: Double

    var isVideo: Bool { ["mp4", "mov", "avi"].contains(url.pathExtension.lowercased()) }
}

/// 处理结果
struct ResultFile: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String

    var ext: String { url.pathExtension.lowercased() }
    var isVideo: Bool { ["mp4", "mov", "avi"].contains(ext) }
    var isImage: Bool { ["jpg", "jpeg", "png", "heic", "webp", "bmp"].contains(ext) }
}

/// 去水印主界面（对应鸿蒙版 RemoveWatermarkView）
struct RemoveWatermarkView: View {
    @ObservedObject private var session = Session.shared

    @State private var mode = 0                                   // 0 图片与视频，1 PDF与文档
    @State private var images: [PickedFile] = []
    @State private var video: PickedFile?
    @State private var documents: [PickedFile] = []

    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var results: [ResultFile] = []

    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var videoSelection: PhotosPickerItem?
    @State private var showDocumentImporter = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Picker("模式", selection: $mode) {
                        Text("图片与视频").tag(0)
                        Text("PDF与文档").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if mode == 0 { mediaSection } else { documentSection }
                }
                .padding(.bottom, 32)
            }
            .background(Color.white)
            .navigationTitle("去水印")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showShare) { ActivityView(items: shareItems) }
        .fileImporter(
            isPresented: $showDocumentImporter,
            allowedContentTypes: documentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { Task { await loadDocuments(urls) } }
        }
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadImages(items) }
        }
        .onChange(of: videoSelection) { _, item in
            guard let item else { return }
            Task { await loadVideo(item) }
        }
    }

    // MARK: - 图片与视频
    private var mediaSection: some View {
        VStack(spacing: 0) {
            selectionBox(
                files: images + (video.map { [$0] } ?? []),
                placeholder: "请在下方选择图片或视频\n(支持批量选择处理)",
                onDelete: { id in
                    images.removeAll { $0.id == id }
                    if video?.id == id { video = nil }
                }
            )

            HStack(spacing: 16) {
                PhotosPicker(selection: $photoSelection,
                             maxSelectionCount: max(1, session.maxSelectCount - images.count),
                             matching: .images) {
                    Text("🖼 传图片").frame(maxWidth: .infinity).frame(height: 48)
                }
                .background(ACColor.cardBG)
                .foregroundStyle(ACColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                PhotosPicker(selection: $videoSelection, matching: .videos) {
                    Text("🎬 传视频").frame(maxWidth: .infinity).frame(height: 48)
                }
                .background(ACColor.cardBG)
                .foregroundStyle(ACColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .font(.system(size: 16))
            .padding(.top, 24)

            processButton(files: images + (video.map { [$0] } ?? []))
            progressBar
            resultSection
        }
        .padding(.horizontal, 16)
    }

    // MARK: - PDF 与文档
    private var documentSection: some View {
        VStack(spacing: 0) {
            selectionBox(
                files: documents,
                placeholder: "请在下方选择 PDF / Word / PPT\n(单个文件最大 30MB)",
                onDelete: { id in documents.removeAll { $0.id == id } }
            )

            Button {
                showDocumentImporter = true
            } label: {
                Text("📄 选择文档").frame(maxWidth: .infinity).frame(height: 48)
            }
            .font(.system(size: 16))
            .background(ACColor.cardBG)
            .foregroundStyle(ACColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 24)

            processButton(files: documents)
            progressBar
            resultSection
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 选择区
    private func selectionBox(files: [PickedFile], placeholder: String, onDelete: @escaping (UUID) -> Void) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(Color(hex: 0xE5E5E5))

            if files.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            } else {
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(files) { file in
                                ZStack(alignment: .topTrailing) {
                                    preview(file)
                                        .frame(width: 120, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        onDelete(file.id)
                                    } label: {
                                        Text("✕")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white)
                                            .frame(width: 20, height: 20)
                                            .background(.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    .padding(4)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    }

                    Text("已选择 \(files.count) 个文件")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(height: 200)
        .padding(.top, 24)
    }

    @ViewBuilder
    private func preview(_ file: PickedFile) -> some View {
        if file.isVideo {
            ZStack {
                Color.black
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
        } else if let image = UIImage(contentsOfFile: file.url.path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Color(hex: 0xF5F6F8)
        }
    }

    // MARK: - 处理按钮
    private func processButton(files: [PickedFile]) -> some View {
        VStack(spacing: 12) {
            if files.count == 1 {
                Text("💡 复杂全屏水印选【智能】，顽固局部水印选【手动】")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xFF9800))
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button {
                        Task { await process() }
                    } label: {
                        Text(isProcessing ? "处理中..." : "✨ 智能去除")
                            .frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .background(isProcessing ? Color(hex: 0xD5D7DC) : ACColor.primary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .disabled(isProcessing)

                    Button {
                        Toast.shared.show("手动框选功能开发中，先试试智能去除")
                    } label: {
                        Text("📝 手动框选")
                            .frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .background(ACColor.cardBG)
                    .foregroundStyle(ACColor.primary)
                    .clipShape(Capsule())
                }
            } else {
                Button {
                    Task { await process() }
                } label: {
                    Text(isProcessing ? "处理中..." : (files.isEmpty ? "✨ 立即去除水印" : "✨ 立即去除水印 (\(files.count))"))
                        .frame(maxWidth: .infinity).frame(height: 50)
                }
                .background(isProcessing || files.isEmpty ? Color(hex: 0xD5D7DC) : ACColor.primary)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .disabled(isProcessing || files.isEmpty)
            }
        }
        .font(.system(size: 16))
        .padding(.top, 24)
    }

    @ViewBuilder
    private var progressBar: some View {
        if isProcessing {
            VStack(spacing: 6) {
                ProgressView(value: min(max(progress, 0), 100), total: 100)
                    .tint(ACColor.primary)
                Text("处理进度 \(Int(min(max(progress, 0), 100)))%")
                    .font(.system(size: 12))
                    .foregroundStyle(ACColor.body)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - 结果区
    @ViewBuilder
    private var resultSection: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("处理结果")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ACColor.title)
                    .padding(.top, 24)

                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        if result.isImage {
                            AsyncImage(url: result.url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            HStack {
                                Image(systemName: result.isVideo ? "film" : "doc")
                                Text(result.filename).font(.system(size: 14)).lineLimit(1)
                            }
                        }

                        HStack(spacing: 16) {
                            Button {
                                Task { await save(result) }
                            } label: {
                                Text(saveButtonTitle(result))
                                    .frame(maxWidth: .infinity).frame(height: 44)
                            }
                            .background(ACColor.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .disabled(isSaving)

                            Button {
                                Task { await shareResult(result) }
                            } label: {
                                Text("📤 用其他应用打开")
                                    .frame(maxWidth: .infinity).frame(height: 44)
                            }
                            .background(ACColor.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .disabled(isSaving)
                        }
                        .font(.system(size: 15))
                    }
                    .padding(12)
                    .background(Color(hex: 0xFAFAFA))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func saveButtonTitle(_ result: ResultFile) -> String {
        if result.isImage || result.isVideo { return "💾 保存到相册" }
        return "💾 保存到本地"
    }

    private var documentTypes: [UTType] {
        var types: [UTType] = [.pdf]
        for ext in ["docx", "doc", "pptx", "ppt"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }

    private var currentFiles: [PickedFile] { mode == 0 ? images + (video.map { [$0] } ?? []) : documents }

    // MARK: - 载入素材
    private func loadImages(_ items: [PhotosPickerItem]) async {
        defer { photoSelection = [] }
        for item in items {
            guard images.count < session.maxSelectCount else {
                Toast.shared.show("最多只能选择 \(session.maxSelectCount) 个文件")
                break
            }
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            // 统一转成 JPEG，兼容后端处理链路
            guard let image = UIImage(data: raw), let jpeg = image.jpegData(compressionQuality: 0.92) else { continue }
            let sizeMB = Double(jpeg.count) / 1024 / 1024
            if sizeMB > session.maxImageMB {
                Toast.shared.show("包含超过 \(Int(session.maxImageMB))MB 的图片！当前最多支持 \(Int(session.maxImageMB))MB，请重新选择")
                continue
            }
            let name = "image_\(UUID().uuidString).jpg"
            let url = URL.temporaryDirectory.appending(path: name)
            do {
                try jpeg.write(to: url)
                images.append(PickedFile(url: url, name: name, sizeMB: sizeMB))
            } catch { continue }
        }
    }

    private func loadVideo(_ item: PhotosPickerItem) async {
        defer { videoSelection = nil }
        guard let movie = try? await item.loadTransferable(type: MovieFile.self) else {
            Toast.shared.show("读取视频失败，请重试")
            return
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: movie.url.path)
        let bytes = (attributes?[.size] as? NSNumber)?.doubleValue ?? 0
        let size = bytes / 1024 / 1024
        let maxMB = session.isVip ? 50.0 : 10.0
        guard size <= maxMB else {
            Toast.shared.show("视频超过 \(Int(maxMB))MB 限制，请重新选择")
            return
        }
        video = PickedFile(url: movie.url, name: movie.url.lastPathComponent, sizeMB: size)
    }

    private func loadDocuments(_ urls: [URL]) async {
        for url in urls {
            guard documents.count < session.maxSelectCount else {
                Toast.shared.show("最多只能选择 \(session.maxSelectCount) 个文件")
                break
            }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            let sizeMB = Double(data.count) / 1024 / 1024
            if sizeMB > session.maxDocumentMB {
                Toast.shared.show("包含超过 30MB 的文档！当前最多支持 30MB")
                continue
            }
            let name = url.lastPathComponent
            let local = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)_\(name)")
            do {
                try data.write(to: local)
                documents.append(PickedFile(url: local, name: name, sizeMB: sizeMB))
            } catch { continue }
        }
    }

    // MARK: - 处理
    private func process() async {
        let files = currentFiles
        guard !files.isEmpty else {
            Toast.shared.show("请先选择文件")
            return
        }
        guard session.isLogin else {
            Toast.shared.show("请先登录")
            return
        }

        // 次数预检查（与鸿蒙版一致：每处理 1 个文件消耗 1 次）
        var pending = files
        if session.points < files.count {
            let canProcess = session.points
            guard canProcess > 0 else {
                Toast.shared.show("次数不足！处理1个文件需要1次，请前往“我的”页面获取次数")
                return
            }
            Toast.shared.show("次数不足，剩余\(canProcess)次，本次只可以处理\(canProcess)个")
            pending = Array(files.prefix(canProcess))
        }

        isProcessing = true
        progress = 0
        results = []

        if mode == 0 {
            await processMedia(pending)
        } else {
            await processDocuments(pending)
        }

        progress = 100
        isProcessing = false
        await session.refreshUserInfo()
    }

    private func processMedia(_ files: [PickedFile]) async {
        var success: [ResultFile] = []
        var failed = 0
        for (index, file) in files.enumerated() {
            do {
                let data = try Data(contentsOf: file.url)
                let response = try await APIClient.shared.removeWatermarkBatch(
                    fileData: data,
                    filename: file.name,
                    fileType: file.isVideo ? "video" : "image"
                ) { percent in
                    progress = Double(index) / Double(files.count) * 100 + percent / Double(files.count)
                }
                if let remaining = response.remainingPoints { session.updatePoints(remaining) }
                if let first = response.results.first,
                   let raw = first.resultUrl,
                   let url = APIClient.shared.absoluteResultURL(raw) {
                    success.append(ResultFile(url: url, filename: first.filename))
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }
        finish(success: success, failed: failed, failureNote: "失败次数已自动返还")
    }

    private func processDocuments(_ files: [PickedFile]) async {
        var success: [ResultFile] = []
        var failed = 0
        for (index, file) in files.enumerated() {
            let ext = file.name.lowercased()
            let endpoint: String
            if ext.hasSuffix(".pdf") { endpoint = "remove-pdf-watermark" }
            else if ext.hasSuffix(".docx") || ext.hasSuffix(".doc") { endpoint = "remove-docx-watermark" }
            else if ext.hasSuffix(".pptx") || ext.hasSuffix(".ppt") { endpoint = "remove-pptx-watermark" }
            else { endpoint = "remove-pdf-watermark" }

            progress = Double(index) / Double(files.count) * 100
            do {
                let data = try Data(contentsOf: file.url)
                let raw = try await APIClient.shared.removeDocument(endpoint: endpoint, fileData: data, filename: file.name)
                if let url = APIClient.shared.absoluteResultURL(raw) {
                    success.append(ResultFile(url: url, filename: file.name))
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }
        finish(success: success, failed: failed, failureNote: "失败次数不扣除")
    }

    private func finish(success: [ResultFile], failed: Int, failureNote: String) {
        if !success.isEmpty {
            results = success
            Toast.shared.show(failed == 0
                ? "全部 \(success.count) 个文件处理成功！"
                : "\(success.count)个成功，\(failed)个失败，\(failureNote)")
        } else {
            Toast.shared.show(session.isLogin ? "处理失败，请稍后重试" : "登录已过期，请重新登录")
        }
    }

    // MARK: - 保存 / 分享
    private func save(_ result: ResultFile) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let local = try await MediaSaver.download(result.url, fallbackExtension: result.isVideo ? ".mp4" : ".png")
            if result.isImage || result.isVideo {
                try await MediaSaver.saveToAlbum(local, isVideo: result.isVideo)
                Toast.shared.show("已保存到相册")
            } else {
                shareItems = [local]
                showShare = true
            }
        } catch {
            Toast.shared.show(error.localizedDescription)
        }
    }

    private func shareResult(_ result: ResultFile) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let local = try await MediaSaver.download(result.url, fallbackExtension: result.isVideo ? ".mp4" : ".png")
            shareItems = [local]
            showShare = true
        } catch {
            Toast.shared.show("文件下载失败，无法分享")
        }
    }
}

/// 视频导入（把相册里的视频拷到沙盒再处理）
struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = URL.temporaryDirectory.appending(path: "video_\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
