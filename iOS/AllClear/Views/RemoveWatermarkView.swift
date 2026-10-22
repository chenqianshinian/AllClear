import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// 去水印主界面（逐项对齐鸿蒙端 pages/index/index.tsx）
struct RemoveWatermarkView: View {
    @ObservedObject private var session = Session.shared
    @ObservedObject private var app = AppState.shared

    @State private var activeTab: FileTab = .media
    @State private var images: [PickedFile] = []
    @State private var document: PickedFile?
    @State private var status: ProcessStatus = .idle
    @State private var results: [ResultFile] = []
    @State private var useAI = false
    @State private var docPrompt = ""

    @State private var replacePhotoItems: [PhotosPickerItem] = []
    @State private var appendPhotoItems: [PhotosPickerItem] = []
    @State private var videoItem: PhotosPickerItem?
    @State private var showDocumentImporter = false

    @State private var previewURLs: [URL] = []
    @State private var previewStartIndex = 0
    @State private var showPreview = false

    @State private var alertKind: IndexAlert?
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var demoVideoOpened = false

    private enum IndexAlert: Identifiable {
        case switchTab(FileTab)
        case charge(count: Int, cost: Int)

        var id: String {
            switch self {
            case .switchTab(let tab): return "switch-\(tab.rawValue)"
            case .charge(let count, let cost): return "charge-\(count)-\(cost)"
            }
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                header

                card
                    .padding(.horizontal, 16)
                    .padding(.top, -64)
                    .zIndex(2)

                resultsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                Spacer(minLength: 28)
            }
        }
        .background(ACColor.gray100)
        .ignoresSafeArea(edges: .top)
        .alert(item: $alertKind) { alert in
            switch alert {
            case .switchTab(let target):
                return Alert(
                    title: Text("切换确认"),
                    message: Text("当前有未保存的进度或结果，切换标签将清空它们。确定要切换吗？"),
                    primaryButton: .default(Text("确定")) {
                        activeTab = target
                        clearAll()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .charge(let count, let cost):
                return Alert(
                    title: Text("扣费确认"),
                    message: Text("本次选择了 \(count) 张图片，使用\(useAI ? "AI 超强去水印" : "常规去水印")，将扣除 \(cost) 次额度（剩余 \(session.points) 次）。确认处理吗？"),
                    primaryButton: .default(Text("确定")) {
                        Task { await execute(prompt: docPrompt) }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            ACImagePreview(urls: previewURLs, startIndex: previewStartIndex)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .fileImporter(
            isPresented: $showDocumentImporter,
            allowedContentTypes: documentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImporterResult(result)
        }
        .onChange(of: replacePhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadImages(items, append: false) }
        }
        .onChange(of: appendPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadImages(items, append: true) }
        }
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            Task { await openVideoEditor(item) }
        }
        .task {
            await loadDemoImageIfNeeded()
            await loadDemoDocumentIfNeeded()
            await loadDemoVideoIfNeeded()
        }
    }

    /// 仅 DEBUG：通过 -demoImage 预置一张带水印样图，便于模拟器端到端验收
    @MainActor
    private func loadDemoImageIfNeeded() async {
        #if DEBUG
        guard images.isEmpty, document == nil,
              ProcessInfo.processInfo.arguments.contains("-demoImage"),
              let source = Bundle.main.url(forResource: "demo_watermark", withExtension: "jpg"),
              let data = try? Data(contentsOf: source) else { return }
        let name = "demo_watermark.jpg"
        let url = URL.temporaryDirectory.appending(path: "demo_\(UUID().uuidString).jpg")
        guard (try? data.write(to: url)) != nil else { return }
        images = [PickedFile(url: url, name: name, sizeMB: Double(data.count) / 1024 / 1024, kind: .image)]
        status = .idle
        results = []
        #endif
    }

    /// 仅 DEBUG：通过 -demoDocument 预置一份带水印 PDF
    @MainActor
    private func loadDemoDocumentIfNeeded() async {
        #if DEBUG
        guard document == nil, images.isEmpty,
              ProcessInfo.processInfo.arguments.contains("-demoDocument"),
              let source = Bundle.main.url(forResource: "demo_document", withExtension: "pdf"),
              let data = try? Data(contentsOf: source) else { return }
        let name = "demo_document.pdf"
        let url = URL.temporaryDirectory.appending(path: "demo_\(UUID().uuidString).pdf")
        guard (try? data.write(to: url)) != nil else { return }
        activeTab = .document
        document = PickedFile(url: url, name: name, sizeMB: Double(data.count) / 1024 / 1024, kind: .document)
        status = .idle
        results = []
        #endif
    }

    /// 仅 DEBUG：通过 -demoVideo 直接进入视频框选页
    @MainActor
    private func loadDemoVideoIfNeeded() async {
        #if DEBUG
        guard !demoVideoOpened,
              ProcessInfo.processInfo.arguments.contains("-demoVideo"),
              let source = Bundle.main.url(forResource: "demo_video", withExtension: "mp4") else { return }
        demoVideoOpened = true
        let url = URL.temporaryDirectory.appending(path: "demo_\(UUID().uuidString).mp4")
        guard (try? FileManager.default.copyItem(at: source, to: url)) != nil else { return }
        let size = await VideoTools.displaySize(for: url)
        try? await Task.sleep(nanoseconds: 350_000_000)
        app.removePath.append(.videoEdit(VideoEditInput(url: url, width: size.width, height: size.height)))
        #endif
    }

    // MARK: - 顶部头图

    private var header: some View {
        ACBlueHeader(topPadding: 64, bottomPadding: 96, horizontalPadding: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("水印天敌")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                Text("一键无痕去除图片/视频/文档水印")
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.blue100.opacity(0.92))
            }
        }
    }

    // MARK: - 核心卡片

    private var card: some View {
        VStack(spacing: 0) {
            segmentedTabs
                .padding(.bottom, 24)

            previewArea
                .padding(.bottom, 24)

            actionButtons
                .padding(.bottom, 24)

            if !images.isEmpty {
                aiRow
                    .padding(.bottom, 16)
            }

            processButton
        }
        .padding(24)
        .acCard(cornerRadius: 24)
    }

    private var segmentedTabs: some View {
        HStack(spacing: 0) {
            tabButton(.media)
            tabButton(.document)
        }
        .padding(4)
        .background(ACColor.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tabButton(_ tab: FileTab) -> some View {
        Button {
            requestTabSwitch(tab)
        } label: {
            Text(tab.title)
                .font(.system(size: 14, weight: activeTab == tab ? .bold : .regular))
                .foregroundStyle(activeTab == tab ? ACColor.blue600 : ACColor.gray500)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(activeTab == tab ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(activeTab == tab ? 0.05 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 文件预览区

    private var previewArea: some View {
        Group {
            if activeTab == .document, let document {
                documentPreview(document)
            } else if !images.isEmpty {
                imageGrid
            } else {
                Text(emptyHintText)
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.gray400)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 192)
        .padding(8)
        .background(ACColor.gray50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            DashedRoundedBorder(cornerRadius: 12)
        }
    }

    private var imageGrid: some View {
        CenteredFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(images) { image in
                imageThumb(image)
            }
            if images.count < session.maxSelectCount {
                addImageTile
            }
        }
    }

    private func imageThumb(_ file: PickedFile) -> some View {
        ZStack(alignment: .topTrailing) {
            FileOrRemoteImage(url: file.url, contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(ACColor.gray200, lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    preview(urls: images.map(\.url), index: images.firstIndex(of: file) ?? 0)
                }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    images.removeAll { $0.id == file.id }
                    results = []
                    status = .idle
                }
            } label: {
                Text("×")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(ACColor.red500)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -8)
        }
        .frame(width: 80, height: 80)
    }

    private var addImageTile: some View {
        PhotosPicker(
            selection: $appendPhotoItems,
            maxSelectionCount: max(1, session.maxSelectCount - images.count),
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ACColor.gray50)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(ACColor.gray300, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                Text("+")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(ACColor.gray400)
            }
            .frame(width: 80, height: 80)
        }
        .buttonStyle(.plain)
    }

    private func documentPreview(_ file: PickedFile) -> some View {
        VStack(spacing: 8) {
            Text("📄")
                .font(.system(size: 36))
            Text(file.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ACColor.gray700)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("文档已就绪")
                .font(.system(size: 12))
                .foregroundStyle(ACColor.gray400)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 选择按钮

    private var actionButtons: some View {
        Group {
            if activeTab == .media {
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $replacePhotoItems,
                        maxSelectionCount: session.maxSelectCount,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text("🖼️ 传图片")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ACColor.blue600)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(ACColor.blue50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(
                        selection: $videoItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Text("🎬 传视频")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ACColor.blue600)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(ACColor.blue50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showDocumentImporter = true
                } label: {
                    Text("📁 从文件选择文档 (PDF/Word/PPT)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(ACColor.blue600)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .acBlueShadow()
            }
        }
    }

    private var aiRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("✨ 启用 AI 超强去水印")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ACColor.gray800)
                Text("消耗 5 次额度/张，效果更佳")
                    .font(.system(size: 12))
                    .foregroundStyle(ACColor.gray500)
            }
            Spacer()
            Toggle("", isOn: $useAI)
                .labelsHidden()
                .tint(ACColor.blue500)
        }
        .padding(12)
        .background(ACColor.gray50)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var processButton: some View {
        Button {
            handleProcess()
        } label: {
            Text(status == .processing ? "处理中..." : "✨ 立即去除水印")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(processButtonColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("remove.process")
        .disabled(status == .processing)
        .acBlueShadow(hasFiles && status != .processing)
    }

    private var processButtonColor: Color {
        if !hasFiles { return ACColor.gray300 }
        if status == .processing { return ACColor.blue400 }
        return ACColor.blue600
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultsSection: some View {
        if status == .success, !results.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("处理结果")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ACColor.gray800)
                    .padding(.bottom, 16)

                resultPreview
                    .padding(.bottom, 16)

                if activeKind == .document {
                    documentRetryPanel
                        .padding(.bottom, 16)
                }

                Button {
                    Task {
                        if activeKind == .document {
                            await openDocument()
                        } else {
                            await saveAllImages()
                        }
                    }
                } label: {
                    Text(activeKind == .document ? "📥 打开/分享文档" : "💾 保存全部到相册")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(ACColor.green500)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("remove.save")

                HStack {
                    Spacer()
                    Button {
                        clearAll()
                    } label: {
                        Text("🗑️ 清空并继续处理")
                            .font(.system(size: 14))
                            .foregroundStyle(ACColor.gray400)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .overlay {
                                Capsule().stroke(ACColor.gray200, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 24)
            }
            .padding(24)
            .acCard(cornerRadius: 16)
        }
    }

    private var resultPreview: some View {
        Group {
            if activeKind == .document {
                VStack(spacing: 8) {
                    Text("✅").font(.system(size: 36))
                    Text("文档处理完成")
                        .font(.system(size: 14))
                        .foregroundStyle(ACColor.gray500)
                }
                .frame(maxWidth: .infinity, minHeight: 128)
            } else {
                CenteredFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(results) { result in
                        FileOrRemoteImage(url: result.url, contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(ACColor.gray200, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                preview(urls: results.map(\.url), index: results.firstIndex(of: result) ?? 0)
                            }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 128)
            }
        }
        .padding(8)
        .background(ACColor.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ACColor.gray200, lineWidth: 1)
        }
    }

    private var documentRetryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("处理结果不满意？")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ACColor.orange800)
            Text("如果部分顽固水印未能自动去除，您可以尝试输入水印文字进行强力擦除：")
                .font(.system(size: 12))
                .foregroundStyle(ACColor.orange600)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                TextField("例如: 绝密资料", text: $docPrompt)
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.gray800)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ACColor.orange100, lineWidth: 1)
                    }

                Button {
                    let prompt = docPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !prompt.isEmpty else {
                        Toast.shared.show("请输入水印文字")
                        return
                    }
                    guard session.isLogin else {
                        Toast.shared.show("请先前往\"我的\"页面登录")
                        app.switchTo(.mine)
                        return
                    }
                    Task { await execute(prompt: prompt) }
                } label: {
                    Text("重试")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(ACColor.orange500)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(status == .processing)
            }
        }
        .padding(16)
        .background(ACColor.orange50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ACColor.orange100, lineWidth: 1)
        }
    }

    // MARK: - 派生状态

    private var hasFiles: Bool { !images.isEmpty || document != nil }

    /// 空态提示：把当前账号的额度限制直接写出来，与官网 / 鸿蒙端 H5 文案一致
    private var emptyHintText: String {
        let count = session.maxSelectCount
        if activeTab == .media {
            let imageMB = Int(session.maxImageMB)
            let videoMB = Int(session.maxVideoMB)
            return "请在下方选择图片或视频\n最多 \(count) 个，图片 ≤ \(imageMB)MB，视频 ≤ \(videoMB)MB"
        }
        let documentMB = Int(session.maxDocumentMB)
        return "请从文件选择文档\n最多 \(count) 个，单个 ≤ \(documentMB)MB"
    }

    private var activeKind: PickedKind? {
        if !images.isEmpty { return .image }
        if document != nil { return .document }
        return results.first?.kind
    }

    private var documentTypes: [UTType] {
        var types: [UTType] = [.pdf]
        for ext in ["doc", "docx", "ppt", "pptx"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }

    // MARK: - 交互

    private func requestTabSwitch(_ target: FileTab) {
        guard activeTab != target else { return }
        if !images.isEmpty || document != nil || status == .processing || status == .success {
            alertKind = .switchTab(target)
        } else {
            activeTab = target
        }
    }

    private func clearAll() {
        withAnimation(.easeInOut(duration: 0.15)) {
            images = []
            document = nil
            status = .idle
            results = []
            docPrompt = ""
        }
        replacePhotoItems = []
        appendPhotoItems = []
        videoItem = nil
    }

    private func handleProcess() {
        guard hasFiles else {
            Toast.shared.show("请先选择文件")
            return
        }
        guard session.isLogin else {
            Toast.shared.show("请先前往\"我的\"页面登录")
            app.switchTo(.mine)
            return
        }

        if activeKind == .image {
            // 与鸿蒙端 / iOS 端既有文案保持一致：AI 超强去水印 5 次/张，常规 1 次/张。
            // ⚠️ 后端 /remove-image-watermark 目前写死 cost = 1，use_ai 不额外计费，
            //    需要后端同步改成 `cost = 5 if use_ai else 1`，否则「说扣 5 实扣 1」。
            let cost = images.count * (useAI ? 5 : 1)
            guard session.points >= cost else {
                Toast.shared.show("剩余 \(session.points) 次，本次需要 \(cost) 次，请先获取额度", duration: 3)
                return
            }
            alertKind = .charge(count: images.count, cost: cost)
        } else {
            Task { await execute(prompt: docPrompt) }
        }
    }

    private func preview(urls: [URL], index: Int) {
        guard !urls.isEmpty else { return }
        previewURLs = urls
        previewStartIndex = index
        showPreview = true
    }

    // MARK: - 素材读取

    @MainActor
    private func loadImages(_ items: [PhotosPickerItem], append: Bool) async {
        defer {
            replacePhotoItems = []
            appendPhotoItems = []
        }
        var loaded: [PickedFile] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.92) else { continue }
            let sizeMB = Double(jpeg.count) / 1024 / 1024
            if sizeMB > session.maxImageMB {
                Toast.shared.show("包含超过 \(Int(session.maxImageMB))MB 的图片！当前最多支持 \(Int(session.maxImageMB))MB，请重新选择")
                continue
            }
            let name = "image_\(UUID().uuidString).jpg"
            let url = URL.temporaryDirectory.appending(path: name)
            do {
                try jpeg.write(to: url)
                loaded.append(PickedFile(url: url, name: name, sizeMB: sizeMB, kind: .image))
            } catch {
                continue
            }
        }
        guard !loaded.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            if append {
                images = Array((images + loaded).prefix(session.maxSelectCount))
            } else {
                images = Array(loaded.prefix(session.maxSelectCount))
            }
            document = nil
            status = .idle
            results = []
            docPrompt = ""
        }
    }

    @MainActor
    private func openVideoEditor(_ item: PhotosPickerItem) async {
        videoItem = nil
        LoadingCenter.shared.show("加载视频...")
        guard let movie = try? await item.loadTransferable(type: MovieFile.self) else {
            LoadingCenter.shared.hide()
            Toast.shared.show("读取视频失败，请重试")
            return
        }
        let size = VideoTools.fileSizeMB(movie.url)
        guard size <= session.maxVideoMB else {
            LoadingCenter.shared.hide()
            Toast.shared.show("视频超过 \(Int(session.maxVideoMB))MB 限制，请重新选择")
            return
        }
        let dimensions = await VideoTools.displaySize(for: movie.url)
        LoadingCenter.shared.hide()
        app.removePath.append(.videoEdit(VideoEditInput(url: movie.url, width: dimensions.width, height: dimensions.height)))
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await loadDocument(url) }
        case .failure:
            break
        }
    }

    @MainActor
    private func loadDocument(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            Toast.shared.show("读取文档失败，请重新选择")
            return
        }
        let sizeMB = Double(data.count) / 1024 / 1024
        guard sizeMB <= session.maxDocumentMB else {
            Toast.shared.show("文档超过 \(Int(session.maxDocumentMB))MB 限制，请重新选择")
            return
        }
        let name = url.lastPathComponent
        let local = URL.temporaryDirectory.appending(path: "doc_\(UUID().uuidString)_\(name)")
        do {
            try data.write(to: local)
        } catch {
            Toast.shared.show("读取文档失败，请重新选择")
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            document = PickedFile(url: local, name: name, sizeMB: sizeMB, kind: .document)
            images = []
            status = .idle
            results = []
            docPrompt = ""
        }
    }

    // MARK: - 处理

    @MainActor
    private func execute(prompt: String) async {
        guard status != .processing else { return }

        let kind: PickedKind
        let files: [PickedFile]
        if !images.isEmpty {
            kind = .image
            files = images
        } else if let document {
            kind = .document
            files = [document]
        } else {
            Toast.shared.show("请先选择文件")
            return
        }

        status = .processing
        results = []
        LoadingCenter.shared.show(files.count > 1 ? "处理中 0/\(files.count)" : "AI处理中...")

        do {
            switch kind {
            case .image:
                try await processImages(files)
            case .document:
                try await processDocument(files[0], prompt: prompt)
            case .video:
                break
            }
            LoadingCenter.shared.hide()
            status = .success
            Toast.shared.success("全部处理完成")
            await session.refreshUserInfo()
        } catch {
            LoadingCenter.shared.hide()
            status = .idle
            let apiError = error as? APIError
            let message = apiError?.errorDescription ?? "网络异常或服务繁忙，请稍后再试"
            Toast.shared.show(message, duration: apiError?.isQuotaError == true ? 3.0 : 2.0)
        }
    }

    @MainActor
    private func processImages(_ files: [PickedFile]) async throws {
        let useAI = self.useAI
        var remoteURLs = [URL?](repeating: nil, count: files.count)
        var firstError: Error?
        var completed = 0

        await withTaskGroup(of: (Int, Result<URL, Error>).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    do {
                        let data = try Data(contentsOf: file.url)
                        let url = try await APIClient.shared.removeImage(
                            fileData: data,
                            filename: file.name,
                            useAI: useAI
                        )
                        return (index, .success(url))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            for await (index, result) in group {
                completed += 1
                if files.count > 1 {
                    LoadingCenter.shared.update("处理中 \(completed)/\(files.count)")
                }
                switch result {
                case .success(let url):
                    remoteURLs[index] = url
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
            }
        }

        if let firstError { throw firstError }
        guard remoteURLs.allSatisfy({ $0 != nil }) else {
            throw APIError.decoding("部分文件未返回处理结果")
        }
        let urls = remoteURLs.compactMap { $0 }

        // 与鸿蒙端一致：先下载到本地做预览，失败则回落到远程 URL
        var localURLs = [URL?](repeating: nil, count: urls.count)
        var previewCount = 0
        await withTaskGroup(of: (Int, URL).self) { group in
            for (index, remote) in urls.enumerated() {
                group.addTask {
                    let ext = remote.pathExtension.isEmpty ? "jpg" : remote.pathExtension
                    let name = "result_\(index)_\(UUID().uuidString).\(ext)"
                    if let local = try? await MediaSaver.download(remote, suggestedName: name) {
                        return (index, local)
                    }
                    return (index, remote)
                }
            }
            for await (index, url) in group {
                previewCount += 1
                if urls.count > 1 {
                    LoadingCenter.shared.update("生成预览 \(previewCount)/\(urls.count)")
                }
                localURLs[index] = url
            }
        }

        let items = zip(localURLs.compactMap { $0 }, files).map { url, file in
            ResultFile(url: url, filename: file.name, kind: .image)
        }
        guard items.count == files.count else {
            throw APIError.decoding("图片处理结果不完整")
        }
        results = items
    }

    @MainActor
    private func processDocument(_ file: PickedFile, prompt: String) async throws {
        let lower = file.name.lowercased()
        let endpoint: String
        if lower.hasSuffix(".pdf") {
            endpoint = "remove-pdf-watermark"
        } else if lower.hasSuffix(".docx") || lower.hasSuffix(".doc") {
            endpoint = "remove-docx-watermark"
        } else if lower.hasSuffix(".pptx") || lower.hasSuffix(".ppt") {
            endpoint = "remove-pptx-watermark"
        } else {
            throw APIError.server(status: 400, message: "不支持的文档格式")
        }

        let data = try Data(contentsOf: file.url)
        let url = try await APIClient.shared.removeDocument(
            endpoint: endpoint,
            fileData: data,
            filename: file.name,
            prompt: prompt.isEmpty ? nil : prompt
        )
        results = [ResultFile(url: url, filename: file.name, kind: .document)]
    }

    // MARK: - 保存 / 分享

    @MainActor
    private func saveAllImages() async {
        guard !results.isEmpty else { return }
        ACDebugLog.log("saveAllImages start count=\(results.count)")
        LoadingCenter.shared.show("保存中...")
        var failures = 0
        var permissionMessage: String?

        for result in results {
            do {
                let local: URL
                if result.url.isFileURL {
                    local = result.url
                } else {
                    local = try await MediaSaver.download(result.url, fallbackExtension: ".jpg")
                }
                try await MediaSaver.saveToAlbum(local, isVideo: result.isVideo)
            } catch {
                failures += 1
                #if DEBUG
                print("[saveAllImages] failed result=\(result.url) error=\(error)")
                #endif
                if let message = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String,
                   message.contains("权限") {
                    permissionMessage = message
                }
            }
        }

        ACDebugLog.log("saveAllImages end failures=\(failures) permission=\(permissionMessage ?? "nil")")
        LoadingCenter.shared.hide()
        if failures == 0 {
            Toast.shared.success("已全部保存到相册")
        } else if let permissionMessage {
            Toast.shared.show(permissionMessage, duration: 3)
        } else {
            Toast.shared.show("部分或全部保存失败")
        }
    }

    @MainActor
    private func openDocument() async {
        guard let result = results.first else { return }
        LoadingCenter.shared.show("正在打开...")
        do {
            let suggested = MediaSaver.documentFileName(original: document?.name ?? result.filename)
            let local = try await MediaSaver.download(result.url, suggestedName: suggested)
            LoadingCenter.shared.hide()
            shareItems = [local]
            showShare = true
        } catch {
            LoadingCenter.shared.hide()
            Toast.shared.show("下载失败")
        }
    }
}
