import SwiftUI

/// 应用根视图：启动页 → 主界面；并负责首启的隐私同意
struct RootView: View {
    @AppStorage("has_agreed_privacy") private var hasAgreedPrivacy = false
    @State private var showSplash = true
    @ObservedObject private var app = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if showSplash {
                SplashView { showSplash = false }
            } else {
                MainShell()

                if !hasAgreedPrivacy {
                    PrivacyConsentView {
                        hasAgreedPrivacy = true
                    }
                }
            }

            LoadingOverlay()
            ToastOverlay()
        }
        .task {
            applyDebugLaunchArgumentsIfNeeded()
            await Session.shared.refreshUserInfo()
            await Session.shared.refreshSystemConfig()
        }
        // 与鸿蒙端 useDidShow 一致：每次回到前台都刷新一次账号额度与审核开关
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await Session.shared.refreshUserInfo()
                await Session.shared.refreshSystemConfig()
            }
        }
    }

    #if DEBUG
    /// 仅用于本地模拟器验收：跳过首启、直达指定页面
    private func applyDebugLaunchArgumentsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetSession") {
            Session.shared.logout()
        }
        if args.contains("-resetOnboarding") {
            hasAgreedPrivacy = false
        }
        if args.contains("-skipOnboarding") {
            hasAgreedPrivacy = true
            showSplash = false
        }
        if let index = args.firstIndex(of: "-startTab"), index + 1 < args.count {
            app.tab = args[index + 1] == "mine" ? .mine : .remove
        }
        if args.contains("-openRecharge") {
            app.tab = .mine
            app.minePath = [.recharge]
        }
        if args.contains("-openTutorial") {
            app.tab = .mine
        }
        if let index = args.firstIndex(of: "-autoLogin"), index + 2 < args.count {
            let email = args[index + 1]
            let password = args[index + 2]
            Task {
                try? await Session.shared.login(email: email, password: password)
            }
        }
    }
    #else
    private func applyDebugLaunchArgumentsIfNeeded() {}
    #endif
}

/// 主界面：底部两个自定义 Tab（去水印 / 我的）
struct MainShell: View {
    @ObservedObject private var app = AppState.shared

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NavigationStack(path: $app.removePath) {
                    RemoveWatermarkView()
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                                .toolbar(.hidden, for: .navigationBar)
                        }
                }
                .opacity(app.tab == .remove ? 1 : 0)
                .allowsHitTesting(app.tab == .remove)
                .zIndex(app.tab == .remove ? 1 : 0)

                NavigationStack(path: $app.minePath) {
                    MineView()
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                                .toolbar(.hidden, for: .navigationBar)
                        }
                }
                .opacity(app.tab == .mine ? 1 : 0)
                .allowsHitTesting(app.tab == .mine)
                .zIndex(app.tab == .mine ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if app.isTabBarVisible {
                CustomTabBar(selection: $app.tab)
            }
        }
        .background(ACColor.gray100.ignoresSafeArea())
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .videoEdit(let input):
            VideoEditView(input: input)
        case .recharge:
            RechargeView()
        }
    }
}
