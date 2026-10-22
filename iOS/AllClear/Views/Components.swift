import SwiftUI
import UIKit
import AVKit
import AVFoundation

// MARK: - 全局导航状态

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable {
        case remove
        case mine
    }

    static let shared = AppState()

    @Published var tab: Tab = .remove
    @Published var removePath: [AppRoute] = []
    @Published var minePath: [AppRoute] = []

    /// 正在上传/处理时置 true：与鸿蒙端 showLoading(mask: true) 对齐，禁止切换 Tab
    @Published var isBusy = false

    var isTabBarVisible: Bool {
        removePath.isEmpty && minePath.isEmpty
    }

    func switchTo(_ tab: Tab) {
        self.tab = tab
    }

    func openRecharge() {
        tab = .mine
        if minePath.isEmpty { minePath.append(.recharge) }
    }

    func popToRoot(_ tab: Tab) {
        switch tab {
        case .remove: removePath.removeAll()
        case .mine: minePath.removeAll()
        }
    }
}

// MARK: - 自定义底部 TabBar（对齐鸿蒙端 Taro tabBar）

struct CustomTabBar: View {
    @Binding var selection: AppState.Tab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(ACColor.gray200)
                .frame(height: 0.5)
            HStack(spacing: 0) {
                tabItem(.remove, icon: "house.fill", title: "去水印")
                tabItem(.mine, icon: "person.fill", title: "我的")
            }
            .padding(.top, 7)
            .padding(.bottom, 5)
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }

    private func tabItem(_ tab: AppState.Tab, icon: String, title: String) -> some View {
        Button {
            if AppState.shared.isBusy {
                Toast.shared.show("正在处理，请稍候…")
                return
            }
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 10, weight: selection == tab ? .medium : .regular))
            }
            .foregroundStyle(selection == tab ? ACColor.blue500 : ACColor.tabInactive)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab == .remove ? "tab.remove" : "tab.mine")
    }
}

// MARK: - flex-wrap justify-center 布局（对应 Taro 的 flex flex-wrap gap-2 justify-center）

struct CenteredFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = compute(maxWidth: maxWidth, subviews: subviews)
        return CGSize(width: maxWidth.isFinite ? maxWidth : result.maxRowWidth, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = compute(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in result.rows {
            let rowWidth = row.reduce(CGFloat(0)) { $0 + result.sizes[$1].width } + spacing * CGFloat(max(0, row.count - 1))
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            let rowHeight = row.map { result.sizes[$0].height }.max() ?? 0
            for index in row {
                let size = result.sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }

    private func compute(maxWidth: CGFloat, subviews: Subviews) -> (rows: [[Int]], sizes: [CGSize], height: CGFloat, maxRowWidth: CGFloat) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for index in sizes.indices {
            let width = sizes[index].width
            let extra = current.isEmpty ? width : currentWidth + spacing + width
            if !current.isEmpty && extra > maxWidth {
                rows.append(current)
                maxRowWidth = max(maxRowWidth, currentWidth)
                current = [index]
                currentWidth = width
            } else {
                current.append(index)
                currentWidth = extra
            }
        }
        if !current.isEmpty {
            rows.append(current)
            maxRowWidth = max(maxRowWidth, currentWidth)
        }

        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            height += row.map { sizes[$0].height }.max() ?? 0
            if i < rows.count - 1 { height += lineSpacing }
        }
        return (rows, sizes, height, maxRowWidth)
    }
}

// MARK: - 本地 / 远程图片

struct FileOrRemoteImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if url.isFileURL {
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    placeholder
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder.overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(ACColor.gray400)
                        }
                    default:
                        placeholder.overlay { ProgressView().tint(ACColor.gray400) }
                    }
                }
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        ACColor.gray100
    }
}

// MARK: - 图片全屏预览（对应 Taro.previewImage）

struct ACImagePreview: View {
    let urls: [URL]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [URL], startIndex: Int = 0) {
        self.urls = urls
        _index = State(initialValue: max(0, min(startIndex, urls.count - 1)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { offset, url in
                    FileOrRemoteImage(url: url, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if urls.count > 1 {
                    Text("\(index + 1) / \(urls.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
            }
        }
        .statusBarHidden(true)
    }
}

// MARK: - 系统分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = UIView()
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 视频播放（AVPlayerViewController）

/// AVPlayerViewController 在嵌入 SwiftUI 时偶尔会继承“隐藏状态栏”的行为，
/// 这里显式保持状态栏可见，避免视频页顶部时间/电量消失。
private final class StatusBarVisiblePlayerViewController: AVPlayerViewController {
    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

struct ACVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    var controls: Bool = true
    var muted: Bool = false
    var autoplay: Bool = true

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = StatusBarVisiblePlayerViewController()
        controller.showsPlaybackControls = controls
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.view.isUserInteractionEnabled = controls
        configure(controller, context: context)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if context.coordinator.currentURL != url {
            configure(uiViewController, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configure(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = muted
        controller.player = player
        context.coordinator.start(player: player, item: item, autoplay: autoplay)
        context.coordinator.currentURL = url
    }

    final class Coordinator {
        var currentURL: URL?
        private var player: AVPlayer?
        private var observer: NSObjectProtocol?

        func start(player: AVPlayer, item: AVPlayerItem, autoplay: Bool) {
            self.player = player
            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            if autoplay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    player.play()
                }
            }
        }

        func stop() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
            player?.pause()
            player = nil
        }

        deinit {
            stop()
        }
    }
}

// MARK: - 视频尺寸 / 视频导入

enum VideoTools {
    /// 读取视频显示尺寸（考虑旋转）
    static func displaySize(for url: URL) async -> CGSize {
        let asset = AVURLAsset(url: url)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                return CGSize(width: 16, height: 9)
            }
            async let natural = track.load(.naturalSize)
            async let transform = track.load(.preferredTransform)
            let (size, t) = try await (natural, transform)
            let transformed = size.applying(t)
            let width = abs(transformed.width)
            let height = abs(transformed.height)
            guard width > 0, height > 0 else { return CGSize(width: 16, height: 9) }
            return CGSize(width: width, height: height)
        } catch {
            return CGSize(width: 16, height: 9)
        }
    }

    static func fileSizeMB(_ url: URL) -> Double {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Double(values?.fileSize ?? 0) / 1024 / 1024
    }
}

/// 把相册视频拷到沙盒临时目录（Taro chooseMedia 的 tempFilePath 等价物）
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

// MARK: - 小工具

extension View {
    /// 用于让自定义头图延伸到状态栏
    func ignoresTopSafeArea() -> some View {
        ignoresSafeArea(edges: .top)
    }
}

// MARK: - 通用菜单行（我的页面 / 充值页）

struct ACMenuRow: View {
    let icon: String
    let title: String
    var showDivider: Bool = true
    var destructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(icon)
                        .font(.system(size: 20))
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(destructive ? ACColor.red500 : ACColor.gray700)
                    Spacer()
                    Text("›")
                        .font(.system(size: 20))
                        .foregroundStyle(ACColor.gray400)
                }
                .padding(.horizontal, 20)
                .frame(height: 56)

                if showDivider {
                    Rectangle()
                        .fill(ACColor.gray100)
                        .frame(height: 1)
                        .padding(.leading, 20)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


// MARK: - DEBUG 日志（写入沙盒 Documents/debug.log，便于模拟器验收排查）

enum ACDebugLog {
    static func log(_ text: String) {
        #if DEBUG
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = documents.appendingPathComponent("debug.log")
        let line = "[\(Date())] \(text)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
        #endif
    }
}
