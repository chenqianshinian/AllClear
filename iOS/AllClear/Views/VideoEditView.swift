import SwiftUI
import UIKit

/// 视频框选页（逐项对齐鸿蒙端 pages/video-edit/index.tsx）
struct VideoEditView: View {
    let input: VideoEditInput

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = Session.shared

    @State private var boxes: [CGRect] = []
    @State private var currentBox: CGRect?
    @State private var dragStart: CGPoint?
    @State private var status: ProcessStatus = .idle
    @State private var processedURL: URL?
    @State private var drawingSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let width = videoWidth(in: geo.size)
            let height = width / max(input.aspectRatio, 0.01)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: 0) {
                        videoContainer(width: width, height: height)

                        if processedURL != nil {
                            resultActions
                        } else {
                            selectionActions(width: width, height: height)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 28)
                }
            }
            .background(ACColor.gray100)
            .ignoresSafeArea(edges: .top)
            .onAppear {
                drawingSize = CGSize(width: width, height: height)
            }
            .onChange(of: width) { _, newValue in
                drawingSize = CGSize(width: newValue, height: newValue / max(input.aspectRatio, 0.01))
            }
        }
    }

    private func videoWidth(in size: CGSize) -> CGFloat {
        let maxWidth = size.width * 0.9
        let maxHeight = size.height * (processedURL == nil ? 0.52 : 0.58)
        let aspect = max(input.aspectRatio, 0.01)
        return min(maxWidth, maxHeight * aspect)
    }

    // MARK: - 头图

    private var header: some View {
        ACBlueHeader(
            color: processedURL == nil ? ACColor.blue500 : ACColor.green500,
            topPadding: 64,
            bottomPadding: 24,
            horizontalPadding: 24,
            onBack: { dismiss() }
        ) {
            VStack(spacing: 8) {
                Text(processedURL == nil ? "框选视频水印" : "处理完成")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text(processedURL == nil
                     ? "请在下方视频截图上手指滑动框选水印位置"
                     : "请预览去水印效果，满意后保存到相册")
                    .font(.system(size: 14))
                    .foregroundStyle(processedURL == nil ? ACColor.blue100 : Color(hex: 0xDCFCE7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 视频容器

    private func videoContainer(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.black
            if let processedURL {
                ACVideoPlayer(url: processedURL, controls: true, muted: false, autoplay: true)
            } else {
                ACVideoPlayer(url: input.url, controls: false, muted: true, autoplay: true)
                drawingLayer
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    private var drawingLayer: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())

                ForEach(Array(boxes.enumerated()), id: \.offset) { index, rect in
                    ZStack {
                        ACColor.red500.opacity(0.2)
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(ACColor.red500, lineWidth: 2)
                        Text("×")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(ACColor.red500.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            _ = boxes.remove(at: index)
                        }
                    }
                }

                if let currentBox {
                    ZStack {
                        ACColor.red500.opacity(0.1)
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(ACColor.red500, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                    .frame(width: currentBox.width, height: currentBox.height)
                    .position(x: currentBox.midX, y: currentBox.midY)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        guard let start = dragStart else { return }
                        let rect = CGRect(
                            x: min(start.x, value.location.x),
                            y: min(start.y, value.location.y),
                            width: abs(value.location.x - start.x),
                            height: abs(value.location.y - start.y)
                        )
                        currentBox = rect
                    }
                    .onEnded { _ in
                        if let rect = currentBox, rect.width > 10, rect.height > 10 {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                boxes.append(rect)
                            }
                        }
                        currentBox = nil
                        dragStart = nil
                    }
            )
        }
    }

    // MARK: - 框选操作

    private func selectionActions(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("框选不满意？请登录访问 AllClear 官网在电脑上进行更精准的批量框选处理。")
                .font(.system(size: 12))
                .foregroundStyle(ACColor.gray400)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .padding(.horizontal, 8)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        boxes.removeAll()
                        currentBox = nil
                    }
                } label: {
                    Text("撤销全部框选")
                        .font(.system(size: 14))
                        .foregroundStyle(ACColor.gray700)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(ACColor.gray200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await processVideo() }
                } label: {
                    Text("确认去除")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(status == .processing ? ACColor.blue400 : ACColor.blue600)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("video.confirm")
                .disabled(status == .processing)
                .acBlueShadow(status != .processing)
            }
            .padding(.top, 24)
        }
        .onAppear {
            drawingSize = CGSize(width: width, height: height)
        }
    }

    // MARK: - 结果操作

    private var resultActions: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    processedURL = nil
                    status = .idle
                    // 结果页与框选页的容器高度不同，旧框的坐标已失效，必须清掉
                    boxes.removeAll()
                    currentBox = nil
                }
            } label: {
                Text("重新框选")
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.gray700)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ACColor.gray200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task { await saveVideo() }
            } label: {
                Text("保存到相册")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ACColor.blue600)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .acBlueShadow()
        }
        .padding(.top, 32)
    }

    // MARK: - 处理 / 保存

    @MainActor
    private func processVideo() async {
        guard session.isLogin else {
            Toast.shared.show("请先登录")
            return
        }
        guard status != .processing else { return }
        guard !boxes.isEmpty else {
            Toast.shared.show("请先在视频画面上框选水印区域")
            return
        }

        let scaleX = drawingSize.width > 0 ? input.width / drawingSize.width : 1
        let scaleY = drawingSize.height > 0 ? input.height / drawingSize.height : 1
        let regions = boxes.map { rect in
            WatermarkRegion(
                x: Int((rect.minX * scaleX).rounded()),
                y: Int((rect.minY * scaleY).rounded()),
                width: Int((rect.width * scaleX).rounded()),
                height: Int((rect.height * scaleY).rounded())
            )
        }

        status = .processing
        LoadingCenter.shared.show("视频AI处理中...")
        do {
            let url = try await APIClient.shared.removeVideo(
                fileURL: input.url,
                filename: input.url.lastPathComponent,
                regions: regions
            )
            LoadingCenter.shared.hide()
            processedURL = url
            status = .success
            Toast.shared.success("处理成功")
            await session.refreshUserInfo()
        } catch {
            LoadingCenter.shared.hide()
            status = .idle
            let message = (error as? APIError)?.errorDescription ?? "网络异常，请稍后重试"
            Toast.shared.show(message, duration: (error as? APIError)?.isQuotaError == true ? 3 : 2)
        }
    }

    @MainActor
    private func saveVideo() async {
        guard let processedURL else { return }
        LoadingCenter.shared.show("保存中...")
        do {
            let ext = processedURL.pathExtension.isEmpty ? "mp4" : processedURL.pathExtension
            let local = try await MediaSaver.download(processedURL, suggestedName: "video(无水印).\(ext)")
            try await MediaSaver.saveToAlbum(local, isVideo: true)
            LoadingCenter.shared.hide()
            Toast.shared.success("已保存到相册")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            LoadingCenter.shared.hide()
            Toast.shared.show("保存失败")
        }
    }
}
