import SwiftUI
import PhotosUI
import UIKit

/// 我的（逐项对齐鸿蒙端 pages/profile/index.tsx）
struct MineView: View {
    @ObservedObject private var session = Session.shared
    @ObservedObject private var app = AppState.shared

    @State private var showLogin = false
    @State private var showContact = false
    @State private var showScanner = false
    @State private var showShare = false
    @State private var showTutorial = false
    @State private var shareItems: [Any] = []
    @State private var showDeleteAccount = false
    @State private var isDeletingAccount = false

    @State private var avatarItem: PhotosPickerItem?
    @State private var nickname = ""
    @State private var isSavingNickname = false
    @FocusState private var nicknameFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            ACColor.gray100.ignoresSafeArea()

            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 40,
                bottomTrailingRadius: 40,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(ACColor.blue500)
            .frame(height: 256)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    userCard
                        .padding(.horizontal, 16)
                        .padding(.top, 160)

                    menuCard
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    if session.isLogin {
                        logoutButton
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }
                }
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .top)

            if showLogin {
                LoginModalView {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showLogin = false
                    }
                }
                .zIndex(50)
                .transition(.opacity)
            }

            if showTutorial {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showTutorial = false
                            }
                        }

                    TutorialView {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showTutorial = false
                        }
                    }
                    .frame(maxWidth: 360)
                }
                .zIndex(60)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showLogin)
        .animation(.easeInOut(duration: 0.15), value: showTutorial)
        .sheet(isPresented: $showContact) {
            CustomerServiceSheet()
                .presentationDetents([.height(380)])
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScanLoginView()
        }
        .alert("确认注销账号？", isPresented: $showDeleteAccount) {
            Button("取消", role: .cancel) {}
            Button("永久注销", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("注销后，账号、剩余次数、会员权益与处理记录将被永久删除且无法恢复，已购买的额度不予退还。")
        }
        .onChange(of: avatarItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(item) }
        }
        .onChange(of: session.user?.nickname) { _, newValue in
            if !nicknameFocused {
                nickname = newValue ?? ""
            }
        }
        .onChange(of: app.tab) { _, tab in
            guard tab == .mine else { return }
            Task {
                await session.refreshUserInfo()
                await session.refreshSystemConfig()
                syncNickname()
            }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-openTutorial") {
                showTutorial = true
            }
            #endif
            syncNickname()
            await session.refreshUserInfo()
            await session.refreshSystemConfig()
            syncNickname()
        }
    }

    // MARK: - 用户卡片

    private var userCard: some View {
        VStack(spacing: 0) {
            avatar
                .offset(y: -64)
                .padding(.bottom, -64)

            if session.isLogin {
                HStack(spacing: 8) {
                    TextField("点击设置昵称", text: $nickname)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ACColor.gray800)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .frame(maxWidth: 220)
                        .focused($nicknameFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await saveNickname() } }
                        .onChange(of: nicknameFocused) { _, focused in
                            if !focused { Task { await saveNickname() } }
                        }

                    if session.isPro {
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ACColor.yellow700)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ACColor.yellow100)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 12)

                Text("点击头像/昵称可修改")
                    .font(.system(size: 12))
                    .foregroundStyle(ACColor.gray400)
                    .padding(.top, 4)

                Rectangle()
                    .fill(ACColor.gray100)
                    .frame(height: 1)
                    .padding(.top, 24)

                VStack(spacing: 4) {
                    Text("\(session.points)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(ACColor.blue600)
                    Text("剩余可用次数")
                        .font(.system(size: 14))
                        .foregroundStyle(ACColor.gray500)
                }
                .padding(.top, 24)
                .padding(.bottom, 4)
            } else {
                Text("未登录")
                    .font(.system(size: 18))
                    .foregroundStyle(ACColor.gray600)
                    .padding(.top, 12)

                Button {
                    showLogin = true
                } label: {
                    Text("邮箱登录 / 注册")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 40)
                        .background(ACColor.blue600)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .acBlueShadow()
                .accessibilityIdentifier("login.entry")
                .padding(.top, 24)
                .padding(.bottom, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 5)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        let avatarURL = URL(string: session.user?.avatarUrl ?? "")
        let content = Group {
            if session.isLogin, let avatarURL, !(session.user?.avatarUrl.isEmpty ?? true) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(Color.white, lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

        if session.isLogin {
            PhotosPicker(selection: $avatarItem, matching: .images, photoLibrary: .shared()) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            ACColor.gray200
            Text("👤")
                .font(.system(size: 36))
                .foregroundStyle(ACColor.gray400)
        }
    }

    // MARK: - 菜单

    private var menuCard: some View {
        VStack(spacing: 0) {
            ACMenuRow(icon: "📖", title: "操作教程") {
                showTutorial = true
            }
            .accessibilityIdentifier("mine.tutorial")

            if session.isLogin {
                ACMenuRow(icon: "💻", title: "扫码登录电脑版") {
                    showScanner = true
                }
            }

            if session.inReview {
                ACMenuRow(icon: "💎", title: "获取使用额度") {
                    showContact = true
                }
            } else {
                ACMenuRow(icon: "💎", title: "充值中心") {
                    app.minePath.append(.recharge)
                }
                .accessibilityIdentifier("mine.recharge")
            }

            ACMenuRow(icon: "👥", title: "邀请好友 (送次数)") {
                shareInvite()
            }

            ACMenuRow(icon: "📞", title: "联系客服", showDivider: session.isLogin) {
                copyCustomerService()
            }

            if session.isLogin {
                ACMenuRow(icon: "🗑️", title: "注销账号", showDivider: false, destructive: true) {
                    showDeleteAccount = true
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }

    private var logoutButton: some View {
        Button {
            session.logout()
            nickname = ""
            Toast.shared.success("已退出登录")
        } label: {
            Text("退出登录")
                .font(.system(size: 16))
                .foregroundStyle(ACColor.red500)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 交互

    @MainActor
    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        LoadingCenter.shared.show("正在注销...")
        defer {
            LoadingCenter.shared.hide()
            isDeletingAccount = false
        }
        do {
            try await session.deleteAccount()
            nickname = ""
            Toast.shared.success("账号已注销")
        } catch {
            let message = (error as? APIError)?.errorDescription ?? "注销失败，请稍后重试"
            Toast.shared.show(message, duration: 3)
        }
    }

    private func syncNickname() {
        nickname = session.user?.nickname ?? ""
    }

    private func shareInvite() {
        let code = session.user?.referralCode ?? ""
        let link = code.isEmpty
            ? "https://allclearwatermark.com"
            : "https://allclearwatermark.com?code=\(code)"
        let text = "🎁 送你免费无痕去水印神器！视频/图片/文档一键处理，超好用！\n\(link)"
        shareItems = [text]
        showShare = true
    }

    private func copyCustomerService() {
        UIPasteboard.general.string = "chenqianshinian"
        Toast.shared.success("客服微信号已复制")
    }

    @MainActor
    private func saveNickname() async {
        guard session.isLogin, !isSavingNickname else { return }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != session.user?.nickname else { return }
        isSavingNickname = true
        defer { isSavingNickname = false }
        do {
            try await APIClient.shared.updateNickname(trimmed)
            session.updateNickname(trimmed)
            nickname = trimmed
        } catch {
            Toast.shared.show("昵称保存失败，请稍后再试")
        }
    }

    @MainActor
    private func uploadAvatar(_ item: PhotosPickerItem) async {
        avatarItem = nil
        guard session.isLogin else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            Toast.shared.show("读取头像失败，请重试")
            return
        }
        let resized = image.ac_resized(maxSide: 512)
        guard let jpeg = resized.jpegData(compressionQuality: 0.88) else {
            Toast.shared.show("读取头像失败，请重试")
            return
        }
        LoadingCenter.shared.show("上传中...")
        do {
            let url = try await APIClient.shared.uploadAvatar(data: jpeg)
            LoadingCenter.shared.hide()
            if !url.isEmpty {
                session.updateAvatar(url)
            }
        } catch {
            LoadingCenter.shared.hide()
            Toast.shared.show("头像上传失败，请稍后再试")
        }
    }
}

// MARK: - 联系客服

struct CustomerServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let wechatId = "chenqianshinian"

    var body: some View {
        VStack(spacing: 0) {
            Text("联系客服")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 24)
                .padding(.bottom, 16)

            Text("如有任何问题或建议，欢迎添加专属客服微信进行反馈交流。")
                .font(.system(size: 14))
                .foregroundStyle(ACColor.gray600)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            HStack(spacing: 0) {
                Text("客服微信：").font(.system(size: 16))
                Text(wechatId)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ACColor.blue600)
            }
            .padding(.bottom, 28)

            Button {
                UIPasteboard.general.string = wechatId
                Toast.shared.success("微信号已复制，请前往微信添加好友")
                dismiss()
            } label: {
                Text("📋 一键复制微信号")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(ACColor.blue600)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button("暂不需要") {
                dismiss()
            }
            .font(.system(size: 14))
            .foregroundStyle(ACColor.gray400)
            .padding(.top, 16)
        }
    }
}

extension UIImage {
    /// 头像上传前压缩，避免大图拖慢上传
    func ac_resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
