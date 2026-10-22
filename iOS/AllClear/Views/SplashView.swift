import SwiftUI

/// 启动页（对应鸿蒙版 SplashView：渐显 + 1.5 秒后进主页）
struct SplashView: View {
    @State private var opacity: Double = 0
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 占位 Logo：等 App 图标定稿后替换为真图标
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [ACColor.tabActive, ACColor.primary],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 110, height: 110)
            .shadow(color: .black.opacity(0.1), radius: 15, y: 8)
            .padding(.bottom, 20)

            Text("AllClear")
                .font(.system(size: 40, weight: .heavy))
                .italic()
                .foregroundStyle(Color(hex: 0x4A5568))
                .tracking(2)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 2)
                .padding(.bottom, 4)

            Text("水印天敌")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(hex: 0x718096))
                .tracking(6)
                .padding(.bottom, 16)

            Text("让每一次分享都纯净无瑕")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: 0xA0AEC0))
                .tracking(2)

            Spacer(minLength: 0)
            Spacer(minLength: 0)

            Text("© 2026 悟用网络科技工作室")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0xCBD5E0))
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.white, Color(hex: 0xF7FAFC), Color(hex: 0xEDF2F7)],
                           startPoint: .top, endPoint: .bottom)
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) { opacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onFinish() }
        }
    }
}
