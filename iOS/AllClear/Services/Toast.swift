import SwiftUI

/// 全局轻提示（对应鸿蒙端 promptAction.showToast / Taro.showToast）
@MainActor
final class Toast: ObservableObject {
    enum Kind {
        case none
        case success
    }

    static let shared = Toast()
    @Published private(set) var message: String?
    @Published private(set) var kind: Kind = .none
    private var task: Task<Void, Never>?

    func show(_ text: String, duration: Double = 2.0) {
        present(text, kind: .none, duration: duration)
    }

    func success(_ text: String, duration: Double = 2.0) {
        present(text, kind: .success, duration: duration)
    }

    private func present(_ text: String, kind: Kind, duration: Double) {
        message = text
        self.kind = kind
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.message = nil
                self?.kind = .none
            }
        }
    }
}

/// 全局 loading（对应鸿蒙端 Taro.showLoading / hideLoading）
@MainActor
final class LoadingCenter: ObservableObject {
    static let shared = LoadingCenter()
    @Published private(set) var title: String?

    var isVisible: Bool { title != nil }

    func show(_ title: String) {
        self.title = title
    }

    func update(_ title: String) {
        guard self.title != nil else { return }
        self.title = title
    }

    func hide() {
        title = nil
    }
}

struct ToastOverlay: View {
    @ObservedObject private var toast = Toast.shared

    var body: some View {
        ZStack {
            if let message = toast.message {
                VStack(spacing: 8) {
                    if toast.kind == .success {
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(minWidth: 110, maxWidth: 280)
                .background(Color.black.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: toast.message)
        .allowsHitTesting(false)
    }
}

struct LoadingOverlay: View {
    @ObservedObject private var loading = LoadingCenter.shared

    var body: some View {
        ZStack {
            if let title = loading.title {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.15)
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(minWidth: 130, maxWidth: 260)
                .background(Color.black.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: loading.title)
    }
}

extension View {
    /// 兼容旧调用：给根视图挂上全局 toast
    func toastOverlay() -> some View {
        overlay { ToastOverlay() }
    }
}
