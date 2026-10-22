import SwiftUI

/// 充值 / 会员（对应鸿蒙版 RechargeDialog，套餐与文案保持一致）
struct RechargeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared
    @State private var selectedIndex = 0

    struct PackageItem {
        let id: StoreManager.ProductID
        let title: String
        let desc: String
        let fallbackPrice: String
        let tag: String?
    }

    private let packages: [PackageItem] = [
        .init(id: .emergency, title: "急救包", desc: "包含 10 次处理额度", fallbackPrice: "¥ 4.90", tag: nil),
        .init(id: .monthly, title: "月卡会员", desc: "30天内包含 200 次额度", fallbackPrice: "¥ 19.90", tag: "推荐"),
        .init(id: .yearly, title: "专业会员", desc: "365天包含 3000 次额度", fallbackPrice: "¥ 99.00", tag: nil)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("升级专业会员").font(.system(size: 18, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundStyle(ACColor.secondary)
                }
            }
            .padding(20)

            Text("解锁大文件与批量处理特权")
                .font(.system(size: 13))
                .foregroundStyle(ACColor.body)
                .padding(.bottom, 16)

            ForEach(Array(packages.enumerated()), id: \.offset) { index, pkg in
                Button {
                    selectedIndex = index
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(pkg.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(ACColor.title)
                                if let tag = pkg.tag {
                                    Text(tag)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ACColor.primary)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(pkg.desc)
                                .font(.system(size: 13))
                                .foregroundStyle(ACColor.body)
                        }
                        Spacer()
                        Text(store.displayPrice(for: pkg.id, fallback: pkg.fallbackPrice))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ACColor.primary)
                    }
                    .padding(16)
                    .background(selectedIndex == index ? ACColor.cardBG : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedIndex == index ? ACColor.primary : ACColor.separator, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Button {
                Task { await pay() }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(store.isStoreReady ? "立即支付" : "支付暂未开通")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(ACColor.primary)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Text("iOS 内购由 App Store 提供，支持随时退款申诉")
                .font(.system(size: 11))
                .foregroundStyle(ACColor.secondary)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .task { await store.loadProducts() }
    }

    private func pay() async {
        guard store.isStoreReady else {
            Toast.shared.show("支付暂未开通，敬请期待")
            return
        }
        do {
            try await store.purchase(packages[selectedIndex].id)
            Toast.shared.show("充值成功！")
            dismiss()
        } catch {
            Toast.shared.show(error.localizedDescription)
        }
    }
}
