import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// 与鸿蒙端（Taro + Tailwind）逐项对齐的配色。
/// 数值取自 tailwind 默认调色板，保证两端视觉一致。
enum ACColor {
    // blue
    static let blue50 = Color(hex: 0xEFF6FF)
    static let blue100 = Color(hex: 0xDBEAFE)
    static let blue200 = Color(hex: 0xBFDBFE)
    static let blue400 = Color(hex: 0x60A5FA)
    static let blue500 = Color(hex: 0x3B82F6)
    static let blue600 = Color(hex: 0x2563EB)

    // gray
    static let gray50 = Color(hex: 0xF9FAFB)
    static let gray100 = Color(hex: 0xF3F4F6)
    static let gray200 = Color(hex: 0xE5E7EB)
    static let gray300 = Color(hex: 0xD1D5DB)
    static let gray400 = Color(hex: 0x9CA3AF)
    static let gray500 = Color(hex: 0x6B7280)
    static let gray600 = Color(hex: 0x4B5563)
    static let gray700 = Color(hex: 0x374151)
    static let gray800 = Color(hex: 0x1F2937)

    // semantic
    static let red500 = Color(hex: 0xEF4444)
    static let green500 = Color(hex: 0x22C55E)
    static let orange50 = Color(hex: 0xFFF7ED)
    static let orange100 = Color(hex: 0xFFEDD5)
    static let orange500 = Color(hex: 0xF97316)
    static let orange600 = Color(hex: 0xEA580C)
    static let orange800 = Color(hex: 0x9A3412)
    static let yellow100 = Color(hex: 0xFEF9C3)
    static let yellow700 = Color(hex: 0xA16207)

    // 兼容旧代码 / 页面
    static let primary = blue500
    static let tabActive = blue500
    static let tabInactive = Color(hex: 0x999999)
    static let tabActiveBG = blue100
    static let title = gray800
    static let body = gray600
    static let secondary = gray400
    static let lightGray = gray100
    static let cardBG = blue50
    static let separator = gray200
}

extension View {
    /// Taro 卡片：bg-white rounded-2xl/3xl shadow-md
    func acCard(cornerRadius: CGFloat = 16, shadow: Bool = true) -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(shadow ? 0.07 : 0), radius: shadow ? 14 : 0, x: 0, y: shadow ? 5 : 0)
    }

    /// 与 Taro 的 `shadow-md shadow-blue-200` 对应
    func acBlueShadow(_ enabled: Bool = true) -> some View {
        shadow(color: enabled ? ACColor.blue200.opacity(0.9) : .clear, radius: enabled ? 10 : 0, x: 0, y: enabled ? 4 : 0)
    }
}

/// 虚线圆角边框（Taro: border-2 border-dashed border-gray-300 rounded-xl）
struct DashedRoundedBorder: View {
    var cornerRadius: CGFloat = 12
    var color: Color = ACColor.gray300
    var lineWidth: CGFloat = 2
    var dash: [CGFloat] = [6, 4]

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
    }
}

/// 页面顶部的蓝色圆角头图（Taro: bg-blue-500 pt-16 pb-24 rounded-b-[40px]）
struct ACBlueHeader<Content: View>: View {
    var color: Color = ACColor.blue500
    var topPadding: CGFloat = 64
    var bottomPadding: CGFloat = 32
    var horizontalPadding: CGFloat = 24
    var roundedBottom: CGFloat = 40
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: roundedBottom,
                        bottomTrailingRadius: roundedBottom,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )

            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.top, topPadding - 12)
                .padding(.leading, 6)
            }
        }
    }
}

/// 通用页面底色
struct ACBackground: View {
    var color: Color = ACColor.gray100
    var body: some View {
        color.ignoresSafeArea()
    }
}
