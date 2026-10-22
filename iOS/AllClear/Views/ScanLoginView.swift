import SwiftUI
import AVFoundation
import CoreImage
import PhotosUI
import UIKit

/// 扫码登录电脑版（对齐鸿蒙端 Taro.scanCode + /auth/scan/confirm）
/// iOS 同时支持相机扫码与从相册识别二维码，便于模拟器验收。
struct ScanLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = Session.shared

    @State private var albumItem: PhotosPickerItem?
    @State private var showAlbumPicker = false
    @State private var handled = false
    @State private var cameraUnavailable = false
    @State private var confirming = false
    @State private var showSuccess = false
    @State private var localError: String?

    var body: some View {
        Group {
            if showSuccess {
                successView
            } else {
                scanPage
            }
        }
        .background(ACColor.gray100.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .photosPicker(isPresented: $showAlbumPicker, selection: $albumItem, matching: .images)
        .onChange(of: albumItem) { _, item in
            guard let item else { return }
            Task { await decodeAlbumQRCode(item) }
        }
        .task {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            ACDebugLog.log("ScanLoginView task args=\(args) handled=\(handled) isLogin=\(session.isLogin)")
            if !handled, let index = args.firstIndex(of: "-demoScanQR"), index + 1 < args.count {
                let code = args[index + 1]
                ACDebugLog.log("ScanLoginView demoScanQR code=\(code)")
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                handle(code: code)
            }
            #endif
        }
    }

    private var header: some View {
        ACBlueHeader(
            topPadding: 64,
            bottomPadding: 24,
            horizontalPadding: 24,
            onBack: { dismiss() }
        ) {
            VStack(spacing: 8) {
                Text("扫码登录电脑版")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("确认后电脑端将直接登录当前账号")
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.blue100)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 32)
        }
    }

    private var scanPage: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 20) {
                    scannerBox
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ACColor.blue200, lineWidth: 3)
                        }
                        .padding(.top, 32)

                    Text(cameraUnavailable
                         ? "当前设备无可用摄像头，请从相册选择电脑端二维码截图"
                         : "请将电脑端登录二维码放入框内，识别后自动确认")
                        .font(.system(size: 14))
                        .foregroundStyle(ACColor.gray500)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        showAlbumPicker = true
                    } label: {
                        Text("🖼️ 从相册选择二维码")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ACColor.blue600)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(ACColor.blue50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .disabled(confirming)

                    if confirming {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("确认登录中...")
                                .font(.system(size: 14))
                                .foregroundStyle(ACColor.gray500)
                        }
                    }

                    if let localError {
                        Text(localError)
                            .font(.system(size: 14))
                            .foregroundStyle(ACColor.red500)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("操作步骤")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ACColor.gray700)
                        Text("1. 在电脑浏览器打开 allclearwatermark.com 并选择扫码登录\n2. 使用本页面对准电脑屏幕上的二维码\n3. 识别成功后，电脑端会自动登录")
                            .font(.system(size: 12))
                            .foregroundStyle(ACColor.gray500)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 32)

                    Spacer(minLength: 24)
                }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 0) {
            header

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(ACColor.green500)
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("电脑端已成功登录！")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ACColor.gray800)
                Text("请回到电脑继续操作")
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.gray500)
            }

            Spacer()
            Spacer()
        }
    }

    private var scannerBox: some View {
        ZStack {
            Color.black
            if cameraUnavailable {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(ACColor.gray500)
                    Text("模拟器 / 无摄像头设备")
                        .font(.system(size: 13))
                        .foregroundStyle(ACColor.gray400)
                }
            } else {
                CameraQRScanner(
                    onCode: { code in
                        handle(code: code)
                    },
                    onUnavailable: {
                        cameraUnavailable = true
                    }
                )
            }

            // 取景框四角
            GeometryReader { proxy in
                let size = proxy.size
                let length: CGFloat = 24
                Path { path in
                    path.move(to: CGPoint(x: 20, y: 20 + length))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                    path.addLine(to: CGPoint(x: 20 + length, y: 20))
                    path.move(to: CGPoint(x: size.width - 20 - length, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: 20 + length))
                    path.move(to: CGPoint(x: 20, y: size.height - 20 - length))
                    path.addLine(to: CGPoint(x: 20, y: size.height - 20))
                    path.addLine(to: CGPoint(x: 20 + length, y: size.height - 20))
                    path.move(to: CGPoint(x: size.width - 20 - length, y: size.height - 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20 - length))
                }
                .stroke(ACColor.blue400, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - 处理扫码结果

    @MainActor
    private func handle(code: String) {
        ACDebugLog.log("ScanLoginView handle code=\(code) handled=\(handled) confirming=\(confirming) isLogin=\(session.isLogin)")
        guard !handled, !confirming else { return }
        guard code.hasPrefix("allclear_login:") else {
            Toast.shared.show("无效的登录二维码")
            return
        }
        guard session.isLogin else {
            Toast.shared.show("请先在应用内登录")
            return
        }
        let sceneId = String(code.dropFirst("allclear_login:".count))
        guard !sceneId.isEmpty else {
            Toast.shared.show("无效的登录二维码")
            return
        }

        handled = true
        confirming = true
        localError = nil

        Task { @MainActor in
            do {
                try await APIClient.shared.confirmScanLogin(sceneId: sceneId)
                ACDebugLog.log("ScanLoginView confirm success scene=\(sceneId)")
                confirming = false
                showSuccess = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            } catch {
                ACDebugLog.log("ScanLoginView confirm error=\(error)")
                confirming = false
                handled = false
                localError = "二维码已过期或无效"
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !showSuccess { localError = nil }
            }
        }
    }

    @MainActor
    private func decodeAlbumQRCode(_ item: PhotosPickerItem) async {
        albumItem = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let ciImage = CIImage(image: image) else {
            Toast.shared.show("读取图片失败，请重试")
            return
        }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        guard let code = features?.compactMap({ $0.messageString }).first else {
            Toast.shared.show("未识别到二维码，请重新选择")
            return
        }
        handle(code: code)
    }
}

// MARK: - 相机扫码预览

private struct CameraQRScanner: UIViewRepresentable {
    let onCode: (String) -> Void
    let onUnavailable: () -> Void

    func makeUIView(context: Context) -> ScannerView {
        let view = ScannerView()
        view.backgroundColor = .black
        context.coordinator.configure(view: view, onCode: onCode, onUnavailable: onUnavailable)
        return view
    }

    func updateUIView(_ uiView: ScannerView, context: Context) {}

    static func dismantleUIView(_ uiView: ScannerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let session = AVCaptureSession()
        private var configured = false
        private var lastCode: String?
        private var onCode: ((String) -> Void)?
        private var onUnavailable: (() -> Void)?

        func configure(view: ScannerView, onCode: @escaping (String) -> Void, onUnavailable: @escaping () -> Void) {
            self.onCode = onCode
            self.onUnavailable = onUnavailable
            guard !configured else { return }
            configured = true

            guard AVCaptureDevice.default(for: .video) != nil else {
                DispatchQueue.main.async { onUnavailable() }
                return
            }

            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                guard granted else {
                    DispatchQueue.main.async { self.onUnavailable?() }
                    return
                }
                DispatchQueue.main.async {
                    self.setupSession(view: view)
                }
            }
        }

        private func setupSession(view: ScannerView) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                onUnavailable?()
                return
            }
            session.beginConfiguration()
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                onUnavailable?()
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()

            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }

        func stop() {
            if session.isRunning {
                session.stopRunning()
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else { return }
            guard value != lastCode else { return }
            lastCode = value
            onCode?(value)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.lastCode = nil
            }
        }
    }
}

private final class ScannerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
