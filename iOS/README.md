# iOS 客户端

SwiftUI 实现的去水印客户端，与 [`../Android`](../Android) 共用同一套后端 API。

## 技术栈

| 项 | 选型 |
| --- | --- |
| 语言 / UI | Swift 5.9 · SwiftUI |
| 最低版本 | iOS 17.0 |
| 工程管理 | XcodeGen（`project.yml` 生成工程，不提交 `.xcodeproj`）|
| 网络 | `URLSession` + 手写 multipart 上传 |
| 选材 | `PhotosPicker`（图片 / 视频）、`fileImporter`（文档）|
| 内购 | StoreKit 2（符合 App Store 审核指南 3.1.1）|
| 依赖 | 无第三方库 |

## 目录结构

```
AllClear/
├── AllClearApp.swift        入口
├── Models/                  数据模型
├── Services/                APIClient · Session · Uploader · MediaSaver · StoreManager · Toast
└── Views/                   RootView · RemoveWatermarkView · MineView · 各类 Sheet
```

## 构建

环境要求：macOS + Xcode 15 以上。

```bash
brew install xcodegen
cd iOS
xcodegen generate
open AllClear.xcodeproj
```

或者用脚本一条命令编译 + 起模拟器 + 截图：

```bash
bash iOS/scripts/run_sim.sh "iPhone 16 Pro"
```

## 为什么用 XcodeGen

`.xcodeproj` 是二进制化的文本工程文件，多人协作时冲突几乎无法合并，也容易在合并中被写坏。用一份可读的 `project.yml` 描述工程，任何人（包括 AI Agent）执行 `xcodegen generate` 就能重建，干净且可 diff。

## 切换后端地址

改 `AllClear/Services/APIClient.swift` 里的 `baseURL`。

## 当前状态

基础链路已跑通：选图 / 选视频 / 选文档 → 上传（带进度）→ 结果预览 → 保存相册或分享。

尚未完成：注册接口、AI 超强去水印开关、文档水印文字提示词、账号注销、AppIcon，以及内购的后端验签接口（`/api/orders/apple-iap`）。

## 无 Mac 时的编译方式

GitHub Actions 的 `macos-15` runner 可以编译出模拟器版 `.app`，不需要签名和开发者账号——见 [`.github/workflows/ios.yml`](../.github/workflows/ios.yml)。
