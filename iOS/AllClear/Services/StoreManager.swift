import Foundation
import StoreKit

/// 会员 / 次数内购（StoreKit 2），对应鸿蒙版 IAPManager。
/// 三个商品全部按「消耗型」设计，与后端 balance + tier 的模型一致。
/// 注：商品需先在 App Store Connect 创建；未配置时 products 为空，界面会提示「支付暂未开通」。
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    enum ProductID: String, CaseIterable {
        case emergency = "com.wuyong.allclear.emergency"  // 急救包，10 次
        case monthly = "com.wuyong.allclear.monthly"      // 月卡会员，200 次 / 30 天
        case yearly = "com.wuyong.allclear.yearly"        // 专业会员，3000 次 / 365 天
    }

    enum StoreError: LocalizedError {
        case notAvailable
        case cancelled
        case pending
        case verifyFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable: return "支付暂未开通，敬请期待"
            case .cancelled: return "已取消支付"
            case .pending: return "支付待确认，完成后会自动发放"
            case .verifyFailed(let msg): return msg
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing = false

    /// 商品是否已上线（ASC 配置完成且审核通过）
    var isStoreReady: Bool { !products.isEmpty }

    func loadProducts() async {
        products = (try? await Product.products(for: ProductID.allCases.map(\.rawValue)).sorted { $0.price < $1.price }) ?? []
    }

    /// 展示价（未开通时回落到鸿蒙版写死的价格）
    func displayPrice(for id: ProductID, fallback: String) -> String {
        products.first { $0.id == id.rawValue }?.displayPrice ?? fallback
    }

    /// 购买 → 后端核验发货 → 完成交易
    func purchase(_ id: ProductID) async throws {
        guard let product = products.first(where: { $0.id == id.rawValue }) else {
            throw StoreError.notAvailable
        }
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreError.verifyFailed("支付凭证校验失败，请联系客服")
            }
            // 后端验签并发货（需要后端提供 /api/orders/apple-iap）
            try await APIClient.shared.verifyApplePurchase(
                productId: id.rawValue,
                signedTransaction: verification.jwsRepresentation
            )
            await transaction.finish()
            await Session.shared.refreshUserInfo()
        case .userCancelled:
            throw StoreError.cancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.verifyFailed("支付失败，请稍后重试")
        }
    }
}
