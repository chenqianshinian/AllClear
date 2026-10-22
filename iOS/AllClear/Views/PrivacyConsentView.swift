import SwiftUI

/// 首启隐私政策弹窗（对应鸿蒙版 PrivacyDialog）
struct PrivacyConsentView: View {
    var onAgree: () -> Void
    @State private var legalType: LegalView.LegalType?
    @State private var showRejectHint = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("服务协议与隐私政策")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("欢迎使用 AllClear——水印天敌！为了更好地保护您的个人信息，请在使用本应用前，仔细阅读并充分理解《用户协议》和《隐私政策》。\n\n我们将严格遵守相关法律法规及隐私政策，保护您的个人信息安全，承诺遵循“阅后即焚”原则，绝不保存或滥用您的文件数据。")
                    HStack(spacing: 12) {
                        Button("查看《用户协议》") { legalType = .agreement }
                        Button("查看《隐私政策》") { legalType = .privacy }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .tint(ACColor.primary)
                }
                .font(.system(size: 14))
                .foregroundStyle(ACColor.body)
                .lineSpacing(8)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                if showRejectHint {
                    Text("需同意《用户协议》和《隐私政策》后才能使用本应用")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.bottom, 12)
                }

                HStack(spacing: 20) {
                    Button {
                        showRejectHint = true
                    } label: {
                        Text("不同意")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .background(ACColor.lightGray)
                    .foregroundStyle(ACColor.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        onAgree()
                    } label: {
                        Text("同意并继续")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .background(ACColor.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
        .sheet(item: $legalType) { type in
            LegalView(type: type)
        }
    }
}
