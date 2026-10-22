import SwiftUI

/// 用户协议 / 隐私政策（文本与鸿蒙版一致）
struct LegalView: View {
    enum LegalType: String, Identifiable {
        case agreement, privacy
        var id: String { rawValue }
        var title: String { self == .agreement ? "用户协议" : "隐私政策" }
    }

    let type: LegalType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("返回") { dismiss() }
                    .foregroundStyle(ACColor.primary)
                    .padding(16)
                Spacer()
                Text(type.title)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("返回").foregroundStyle(.clear).padding(16)
            }
            .frame(height: 56)
            .background(Color.white)
            .overlay(alignment: .bottom) { Rectangle().fill(ACColor.separator).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if type == .agreement { agreementContent } else { privacyContent }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(Color.white)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(ACColor.title)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(ACColor.body)
            .lineSpacing(7)
            .padding(.bottom, 16)
    }

    @ViewBuilder
    private var agreementContent: some View {
        bodyText("欢迎使用 AllClear——水印天敌（以下简称“本服务”）。在使用本服务前，请您务必仔细阅读并透彻理解本协议。一旦您使用本服务，即表示您已阅读、理解并同意接受本协议的所有条款。")
        sectionTitle("1. 服务说明")
        bodyText("本服务主要提供针对图片、视频、PDF、Word及PPT等文件的AI水印去除功能。我们致力于提供高质量的处理结果，但受限于技术客观条件，我们无法保证100%的完美去除效果。")
        sectionTitle("2. 阅后即焚与文件处理机制")
        bodyText("本平台秉持最高级别的数据安全原则，采用“阅后即焚”机制。您上传的所有原文件以及处理后的文件仅在系统内存或临时目录中进行瞬时处理。一旦处理完成并由您下载（或处理失败、超时），相关文件将立即被永久销毁，我们绝不保存、备份或滥用您的任何文件。")
        sectionTitle("3. 知识产权与免责声明")
        bodyText("• 您承诺，您上传至本平台进行处理的文件，您均拥有合法的著作权或已获得版权人的充分授权。\n• 您不得使用本服务去除他人享有版权的作品上的保护性水印，并用于商业牟利、侵权传播等非法用途。\n• 免责声明：本平台仅提供中立的技术处理工具。因您使用本服务处理文件所引发的任何版权纠纷、法律诉讼及经济赔偿，均由您自行承担，本平台不承担任何直接或间接的法律责任。")
        sectionTitle("4. 账号与服务变更")
        bodyText("本平台有权根据业务发展需要，随时调整免费处理次数、计费规则、订阅价格及产品功能。如有重大变更，我们将通过系统公告或界面提示的方式告知用户。")
    }

    @ViewBuilder
    private var privacyContent: some View {
        bodyText("AllClear——水印天敌 非常重视您的隐私保护。本《隐私政策》旨在向您说明我们在提供服务时收集、使用、存储及保护您个人信息的方式。")
        sectionTitle("1. 极简的数据收集声明")
        bodyText("为了向您提供基础的账号注册、登录及去水印额度追踪服务，我们仅收集以下极其有限的必要信息：\n• 账号标识：您注册时提供的邮箱地址、手机号码或第三方授权标识（如微信UnionID）。\n• 操作日志：仅记录您处理文件的类型（如视频、图片）及文件大小，用于扣减您的可用处理次数和宏观业务统计。")
        sectionTitle("2. 文件的“零保留”承诺")
        bodyText("我们承诺，您上传用于去水印的图片、视频、文档等一切媒体文件，均遵循“阅后即焚”原则。系统仅在内存及安全沙盒内完成自动化处理，完成后原文件和结果文件将被系统自动彻底删除。我们不会将其用于模型训练、数据分析或任何其他商业用途。")
        sectionTitle("3. 设备权限调用说明")
        bodyText("为提供核心业务功能，我们可能需要您授权以下设备权限：\n• 存储/相册权限：仅用于您在App内主动选择需要去水印的图片或视频文件，以及保存处理后的文件到本地设备。我们绝不会在后台秘密读取您的相册内容。\n• 网络访问权限：用于上传待处理文件及下载处理完成的文件。")
        sectionTitle("4. 第三方SDK信息披露")
        bodyText("为了实现应用的某些特定功能，我们接入了第三方SDK。我们严格要求第三方SDK提供方遵守相关数据保护法律法规：\n• 微信开放平台SDK：用于实现微信一键授权登录。可能会收集您的设备标识符、网络状态信息及微信基础公开信息（如头像、昵称、UnionID）。\n• 华为Ads SDK：用于提供激励视频广告服务以获取免费去水印次数。可能会收集设备标识符及广告互动数据。\n• 华为IAP SDK：用于提供应用内支付功能（若启用）。可能会收集订单及设备环境信息。")
        sectionTitle("5. 账号注销与数据删除")
        bodyText("您拥有完全的账号控制权。若您希望注销账号，可通过“我的 - 联系客服”或App内注销功能提交申请。账号注销后，我们将在15个工作日内彻底删除您的个人信息及历史处理记录，且无法恢复。")
        sectionTitle("6. 开发者主体信息")
        bodyText("本应用由 马鞍山市雨山区悟用网络科技工作室（个体工商户） 开发并运营。如有隐私相关疑问，请通过客服渠道联系我们。")
    }
}
