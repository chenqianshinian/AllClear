import SwiftUI
import UIKit

/// 我的（对应鸿蒙版 MineView）
struct MineView: View {
    @ObservedObject private var session = Session.shared
    @State private var showLogin = false
    @State private var showRecharge = false
    @State private var showTutorial = false
    @State private var showCustomerService = false
    @State private var legalType: LegalView.LegalType?
    @State private var agreedPrivacy = true   // 首启已通过全局弹窗同意
    @State private var isCheckingIn = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xF7F8FA).ignoresSafeArea()

            // 顶部蓝色背景
            Color(hex: 0x3072F6)
                .frame(height: 200)
                .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    userCard
                    menuCard
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showLogin) { LoginSheet { } }
        .sheet(isPresented: $showRecharge) {
            RechargeView().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView { showTutorial = false }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCustomerService) { CustomerServiceView() }
        .sheet(item: $legalType) { LegalView(type: $0) }
        .sheet(isPresented: $showShare) { ActivityView(items: [shareText]) }
        .task { await session.refreshUserInfo() }
    }

    // MARK: - 用户卡片
    private var userCard: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color(hex: 0xEFEFEF)).frame(width: 80, height: 80)
                if session.isLogin, let url = session.user?.avatarUrl, let imageURL = URL(string: url), !url.isEmpty {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Text("👤").font(.system(size: 40))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Text("👤").font(.system(size: 40))
                }
            }
            .padding(.top, -40)
            .padding(.bottom, 16)

            if session.isLogin {
                Text(session.user?.nickname.isEmpty == false ? session.user!.nickname : "用户")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ACColor.title)

                HStack(spacing: 0) {
                    Text("剩余次数: ").font(.system(size: 14)).foregroundStyle(ACColor.body)
                    Text("\(session.points)").font(.system(size: 16, weight: .bold)).foregroundStyle(ACColor.primary)
                    Text(" 次").font(.system(size: 14)).foregroundStyle(ACColor.body)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                HStack(spacing: 16) {
                    Button {
                        Task { await checkIn() }
                    } label: {
                        Text(isCheckingIn ? "签到中..." : "📅 每日签到领次数")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(Color(hex: 0xFFF5E6))
                    .foregroundStyle(Color(hex: 0xFF8C00))
                    .clipShape(Capsule())
                    .disabled(isCheckingIn)

                    Button {
                        session.logout()
                        Toast.shared.show("已退出登录")
                    } label: {
                        Text("退出登录")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(ACColor.lightGray)
                    .foregroundStyle(Color(hex: 0xFF4D4F))
                    .clipShape(Capsule())
                }
                .padding(.bottom, 24)

            } else {
                Text("未登录")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ACColor.title)

                HStack(spacing: 16) {
                    Button {
                        guard agreedPrivacy else {
                            Toast.shared.show("请先阅读并同意用户协议和隐私政策")
                            return
                        }
                        showLogin = true
                    } label: {
                        Text("邮箱登录")
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(ACColor.primary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                    Button {
                        Toast.shared.show("Apple 登录待开通")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                            Text("Apple 登录")
                        }
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .opacity(0.45)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                HStack(spacing: 4) {
                    Button {
                        agreedPrivacy.toggle()
                    } label: {
                        Image(systemName: agreedPrivacy ? "checkmark.square.fill" : "square")
                            .foregroundStyle(agreedPrivacy ? ACColor.primary : ACColor.secondary)
                    }
                    Text("我已阅读并同意").font(.system(size: 12)).foregroundStyle(ACColor.secondary)
                    Text("《用户协议》").font(.system(size: 12)).foregroundStyle(ACColor.primary)
                        .onTapGesture { legalType = .agreement }
                    Text("和").font(.system(size: 12)).foregroundStyle(ACColor.secondary)
                    Text("《隐私政策》").font(.system(size: 12)).foregroundStyle(ACColor.primary)
                        .onTapGesture { legalType = .privacy }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
        .padding(.horizontal, 20)
        .padding(.top, 100)
    }

    // MARK: - 功能列表
    private var menuCard: some View {
        VStack(spacing: 0) {
            menuItem("📖", "操作教程") { showTutorial = true }
            divider
            menuItem("👥", "邀请好友 (送次数)") { shareInvite() }
            divider
            menuItem("💎", "升级专业会员") {
                guard session.isLogin else { Toast.shared.show("请先登录"); return }
                showRecharge = true
            }
            divider
            menuItem("📞", "联系客服") { showCustomerService = true }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var divider: some View {
        Rectangle().fill(ACColor.lightGray).frame(height: 1).padding(.horizontal, 16)
    }

    private func menuItem(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(icon).font(.system(size: 20)).padding(.trailing, 4)
                Text(title).font(.system(size: 16)).foregroundStyle(ACColor.title)
                Spacer()
                Text(">").font(.system(size: 16)).foregroundStyle(Color(hex: 0xCCCCCC))
            }
            .frame(height: 60)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 动作
    private func checkIn() async {
        guard session.isLogin else {
            Toast.shared.show("请先登录")
            return
        }
        isCheckingIn = true
        defer { isCheckingIn = false }
        do {
            let result = try await APIClient.shared.checkin()
            Toast.shared.show(result.message)
            session.updatePoints(result.balance)
        } catch {
            let message = error.localizedDescription
            Toast.shared.show(message.contains("今日已签到") ? "今日已签到，请明天再来~" : "签到失败，请检查网络")
        }
    }

    private func shareInvite() {
        guard session.isLogin else {
            Toast.shared.show("请先登录")
            return
        }
        let code = session.user?.referralCode ?? ""
        shareText = "一键免费批量去除图片、视频、文档水印，快来试试！ https://allclearwatermark.com?code=\(code)"
        showShare = true
    }

    @State private var showShare = false
    @State private var shareText = ""
}

/// 系统分享面板（对应鸿蒙版 ShareController）
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 联系客服（对应鸿蒙版 CustomerServiceDialog）
struct CustomerServiceView: View {
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
                .foregroundStyle(ACColor.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            HStack(spacing: 0) {
                Text("客服微信：").font(.system(size: 16))
                Text(wechatId).font(.system(size: 18, weight: .medium)).foregroundStyle(ACColor.primary)
            }
            .padding(.bottom, 32)

            Button {
                UIPasteboard.general.string = wechatId
                Toast.shared.show("微信号已复制，请前往微信添加好友")
                dismiss()
            } label: {
                Text("📋 一键复制微信号")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(ACColor.primary)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(.horizontal, 24)

            Button("暂不需要") { dismiss() }
                .font(.system(size: 14))
                .foregroundStyle(ACColor.secondary)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .presentationDetents([.height(360)])
    }
}
