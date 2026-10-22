import SwiftUI

/// 充值中心（逐项对齐鸿蒙端 pages/recharge/index.tsx）
struct RechargeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var session = Session.shared
    @ObservedObject private var store = StoreManager.shared

    @State private var selected: StoreManager.ProductID = .emergency
    @State private var showContact = false
    @State private var showStoreUnavailable = false
    @State private var isPaying = false

    private struct PackageItem: Identifiable {
        let id: StoreManager.ProductID
        let name: String
        let desc: String
        let price: Double

        var priceText: String { "￥\(Self.trim(price))" }

        static func trim(_ value: Double) -> String {
            var text = String(format: "%.2f", value)
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
            return text
        }
    }

    private let allPackages: [PackageItem] = [
        PackageItem(id: .emergency, name: "急救包", desc: "包含 10 次处理额度", price: 4.90),
        PackageItem(id: .monthly, name: "月卡会员", desc: "30天内包含 200 次额度", price: 19.90),
        PackageItem(id: .yearly, name: "专业会员", desc: "365天内包含 3000 次额度", price: 99.00)
    ]

    private var packages: [PackageItem] {
        if session.isPro {
            return allPackages.filter { $0.id == .emergency }
        }
        return allPackages
    }

    private var selectedPackage: PackageItem {
        packages.first { $0.id == selected } ?? packages[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if session.inReview {
                reviewMode
            } else {
                normalMode
            }
        }
        .background(ACColor.gray50.ignoresSafeArea())
        .task {
            await store.loadProducts()
            await session.refreshSystemConfig()
            await session.refreshUserInfo()
            if session.isPro, selected != .emergency {
                selected = .emergency
            }
        }
        .sheet(isPresented: $showContact) {
            CustomerServiceSheet()
                .presentationDetents([.height(380)])
        }
        .alert("请使用网页版完成充值", isPresented: $showStoreUnavailable) {
            Button("打开网页版充值") {
                if let url = URL(string: "https://allclearwatermark.com") { openURL(url) }
            }
            Button("联系客服") { showContact = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("从源码编译的构建不会自动带上 App Store 商品（需要 App Store Connect 商品与后端验签接口）。你可以直接在浏览器打开官网完成充值，额度会同步到同一账号。")
        }
    }

    private var topBar: some View {
        ZStack {
            Text("充值中心")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ACColor.gray800)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ACColor.gray700)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 4)
        .background(ACColor.gray50)
    }

    // MARK: - 审核模式

    private var reviewMode: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                Text("🔧")
                    .font(.system(size: 48))
                    .padding(.bottom, 16)
                Text("系统升级维护中")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ACColor.gray800)
                    .padding(.bottom, 8)
                Text("因平台规范要求，应用内暂不开放充值服务。请您联系在线客服获取更多使用额度。")
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.gray500)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.bottom, 28)

                Button {
                    showContact = true
                } label: {
                    Text("联系客服获取额度")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(ACColor.blue600)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .acBlueShadow()
            }
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
            .padding(.horizontal, 16)
            Spacer()
            Spacer()
        }
    }

    // MARK: - 正常充值

    private var normalMode: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("充值点数即刻到账")
                            .font(.system(size: 14))
                            .foregroundStyle(ACColor.gray500)
                        Text("全网最低价")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(ACColor.blue600)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)

                    ForEach(packages) { package in
                        packageCard(package)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            bottomBar
        }
    }

    private func packageCard(_ package: PackageItem) -> some View {
        let isSelected = selected == package.id
        return Button {
            selected = package.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(package.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ACColor.gray800)
                    Spacer()
                    Text(store.isStoreReady
                         ? store.displayPrice(for: package.id, fallback: package.priceText)
                         : package.priceText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ACColor.red500)
                }
                Text(package.desc)
                    .font(.system(size: 14))
                    .foregroundStyle(ACColor.gray500)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? ACColor.blue50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? ACColor.blue500 : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button {
                pay()
            } label: {
                Group {
                    if isPaying {
                        ProgressView().tint(.white)
                    } else {
                        Text("立即支付 \(displayPrice)")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(ACColor.blue600)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .acBlueShadow()
            .accessibilityIdentifier("recharge.pay")
            .disabled(isPaying)

            Text("iOS 内购由 App Store 提供，支持随时退款申诉")
                .font(.system(size: 11))
                .foregroundStyle(ACColor.gray400)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }

    private var displayPrice: String {
        if store.isStoreReady {
            return store.displayPrice(for: selectedPackage.id, fallback: selectedPackage.priceText)
        }
        return selectedPackage.priceText
    }

    // MARK: - 支付

    private func pay() {
        guard !isPaying else { return }
        guard session.isLogin else {
            Toast.shared.show("请先登录")
            return
        }
        guard store.isStoreReady, store.product(for: selectedPackage.id) != nil else {
            showStoreUnavailable = true
            return
        }

        isPaying = true
        LoadingCenter.shared.show("正在准备支付...")

        Task { @MainActor in
            defer { isPaying = false }
            do {
                try await store.purchase(selectedPackage.id)
                LoadingCenter.shared.hide()
                Toast.shared.success("支付成功！")
                await session.refreshUserInfo()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } catch let error as StoreManager.StoreError {
                LoadingCenter.shared.hide()
                switch error {
                case .cancelled:
                    Toast.shared.show("支付已取消")
                default:
                    Toast.shared.show(error.errorDescription ?? "支付失败，请稍后重试")
                }
            } catch {
                LoadingCenter.shared.hide()
                Toast.shared.show("支付失败，请稍后重试")
            }
        }
    }
}
