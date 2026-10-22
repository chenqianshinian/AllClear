import SwiftUI

/// 全局轻提示（对应鸿蒙版 promptAction.showToast）
@MainActor
final class Toast: ObservableObject {
    static let shared = Toast()
    @Published var message: String?
    private var task: Task<Void, Never>?

    func show(_ text: String, duration: Double = 2.0) {
        message = text
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled { message = nil }
        }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject private var toast = Toast.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toast.message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.bottom, 80)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast.message)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
