import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// 与鸿蒙版对齐的配色
enum ACColor {
    static let primary = Color(hex: 0x3072F6)
    static let tabActive = Color(hex: 0x1296db)
    static let tabActiveBG = Color(hex: 0xE8F4FF)
    static let title = Color(hex: 0x333333)
    static let body = Color(hex: 0x666666)
    static let secondary = Color(hex: 0x999999)
    static let lightGray = Color(hex: 0xF5F5F5)
    static let cardBG = Color(hex: 0xF2F6FF)
    static let separator = Color(hex: 0xF0F0F0)
}
