import XCTest

/// iOS 26.5 模拟器 runtime 下 SKTestSession 存在已知问题（StoreKit 配置无法通过
/// xcodebuild test 注入），这里做结构校验；真实商品加载请在 Xcode Run 中使用
/// AllClear.storekit（Scheme 已配置）验证。
final class StoreKitConfigTests: XCTestCase {
    func testStoreKitConfigurationFileIsWellFormed() throws {
        guard let url = Bundle(for: Self.self).url(forResource: "AllClear", withExtension: "storekit") else {
            return XCTFail("测试包中缺少 AllClear.storekit")
        }
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("AllClear.storekit 不是合法 JSON")
        }

        XCTAssertNotNil(root["appPolicies"], "缺少 appPolicies")

        guard let version = root["version"] as? [String: Any],
              let major = version["major"] as? Int else {
            return XCTFail("缺少 version")
        }
        XCTAssertGreaterThanOrEqual(major, 4, "StoreKit 配置版本过低")

        guard let products = root["products"] as? [[String: Any]] else {
            return XCTFail("缺少 products")
        }
        XCTAssertEqual(products.count, 3)

        let expected: [String: String] = [
            "com.wuyong.allclear.pack_10": "Consumable",
            "com.wuyong.allclear.pro_monthly": "Consumable",
            "com.wuyong.allclear.pro_yearly": "Consumable"
        ]
        for product in products {
            guard let productID = product["productID"] as? String,
                  let type = product["type"] as? String else {
                return XCTFail("商品缺少 productID/type")
            }
            XCTAssertEqual(expected[productID], type, "商品 \(productID) 类型不正确")
            let localizations = product["localizations"] as? [[String: Any]] ?? []
            XCTAssertFalse(localizations.isEmpty, "商品 \(productID) 缺少本地化")
        }
    }
}
