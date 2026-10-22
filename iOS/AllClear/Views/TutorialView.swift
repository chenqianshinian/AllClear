import SwiftUI

/// 新手教程（对应鸿蒙版 TutorialDialog，五步引导）
struct TutorialView: View {
    var onClose: () -> Void
    @State private var step = 0

    private let steps: [(title: String, desc: String)] = [
        ("第一步：登录", "在\u{201C}我的\u{201D}页面登录账号，获取免费去水印次数。"),
        ("第二步：选择功能", "根据需要选择\u{201C}图片与视频\u{201D}或\u{201C}PDF与文档\u{201D}选项卡。"),
        ("第三步：选择文件", "点击对应按钮，从手机相册或文件中选择需要处理的素材。"),
        ("第四步：立即去除", "点击亮起的\u{201C}✨ 立即去除水印\u{201D}按钮，等待云端处理完成。"),
        ("第五步：预览与保存", "处理完成后可直接预览，不满意可重试，满意则点击保存到设备。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("快速上手指南")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 24)
                .padding(.bottom, 20)

            TabView(selection: $step) {
                ForEach(0..<steps.count, id: \.self) { index in
                    VStack {
                        Text("\(index + 1)")
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundStyle(ACColor.tabActiveBG)
                            .padding(.bottom, 16)

                        Text(steps[index].title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(ACColor.title)
                            .padding(.bottom, 12)

                        Text(steps[index].desc)
                            .font(.system(size: 14))
                            .foregroundStyle(ACColor.body)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 24)

                        if index == 2 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("💡 小贴士：")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ACColor.primary)
                                Text("图片与文档：支持一键批量处理，省时省力。")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ACColor.body)
                                Text("视频处理：因需精准定位水印，请手动框选区域，暂支持单选。")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ACColor.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(ACColor.cardBG)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 380)

            HStack {
                if step > 0 {
                    Button("上一步") { step -= 1 }
                        .frame(width: 130)
                        .buttonStyle(.bordered)
                        .tint(ACColor.body)
                } else {
                    Button("跳过教程") { onClose() }
                        .frame(width: 130)
                        .buttonStyle(.bordered)
                        .tint(ACColor.secondary)
                }

                Spacer()

                if step < steps.count - 1 {
                    Button("下一步") { step += 1 }
                        .frame(width: 130)
                        .buttonStyle(.borderedProminent)
                        .tint(ACColor.tabActive)
                } else {
                    Button("立即体验") { onClose() }
                        .frame(width: 130)
                        .buttonStyle(.borderedProminent)
                        .tint(ACColor.tabActive)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}
