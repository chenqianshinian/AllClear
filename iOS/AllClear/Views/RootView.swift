import SwiftUI

/// 应用根视图：启动页 → 主界面；并负责首启的隐私同意与新手教程
struct RootView: View {
    @AppStorage("has_agreed_privacy") private var hasAgreedPrivacy = false
    @AppStorage("has_shown_tutorial") private var hasShownTutorial = false
    @State private var showSplash = true
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            if showSplash {
                SplashView { showSplash = false }
            } else {
                MainTabView()

                if !hasAgreedPrivacy {
                    PrivacyConsentView {
                        hasAgreedPrivacy = true
                        if !hasShownTutorial {
                            showTutorial = true
                        }
                    }
                }

                if showTutorial {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    TutorialView {
                        hasShownTutorial = true
                        showTutorial = false
                    }
                }
            }
        }
        .task {
            // 启动即刷新一次用户信息，保证次数/会员状态是最新的
            await Session.shared.refreshUserInfo()
        }
        .toastOverlay()
    }
}

/// 主界面：底部两个 Tab（去水印 / 我的）
struct MainTabView: View {
    var body: some View {
        TabView {
            RemoveWatermarkView()
                .tabItem { Label("去水印", systemImage: "wand.and.stars") }

            MineView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(ACColor.tabActive)
    }
}
