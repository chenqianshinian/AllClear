<div align="center">

# AllClear · 水印天敌

**一个应用，免费去除图片 / 视频 / 文档等常用素材的水印**

Android（Kotlin + Jetpack Compose）· iOS（SwiftUI）双端原生客户端

[官网](https://allclearwatermark.com) · [功能](#功能清单) · [构建](#快速开始) · [架构](#架构设计) · [常见问题](#常见问题)

</div>

---

## 这是什么

AllClear（水印天敌）是一个多端去水印工具。用户选择图片、视频或文档，上传到云端完成 AI 去水印，几秒后下载处理结果并保存到相册 / 文件。

本仓库开源的是**两套原生客户端**：

| 平台 | 语言 / UI 框架 | 状态 |
| --- | --- | --- |
| Android | Kotlin 2.2 + Jetpack Compose (Material 3) | 已上架 |
| iOS | Swift 5.9 + SwiftUI | 开发中 |

> 服务端（FastAPI + 算法）与鸿蒙、小程序版本不在本仓库内。
> 客户端只是薄壳，真正的算力与计费都在后端。

<!--
## 截图

把 3–5 张截图放进 docs/screenshots/ 后，删掉这段注释即可显示。

<p align="center">
  <img src="docs/screenshots/android-home.png" width="240" alt="Android 首页">
  <img src="docs/screenshots/android-result.png" width="240" alt="处理结果">
  <img src="docs/screenshots/ios-home.png" width="240" alt="iOS 首页">
</p>
-->

## 功能清单

| 功能 | Android | iOS |
| --- | :---: | :---: |
| 相册多选图片、批量处理 | ✅ | ✅ |
| 选择视频（单个） | ✅ | ✅ |
| PDF / Word / PPT 文档去水印 | ✅ | ✅ |
| 上传进度 + 处理进度回显 | ✅ | ✅ |
| 结果预览、保存到相册 / 文件、系统分享 | ✅ | ✅ |
| 邮箱登录 / 注册 | ✅ | 🚧 仅登录 |
| 每日签到领次数 | ✅ | ✅ |
| 会员与次数充值 | ✅ 支付宝 / 微信扫码 | 🚧 StoreKit 内购（后端验签接口未接通）|
| 首启隐私强确认、用户协议、隐私政策 | ✅ | ✅ |
| 新手教程、联系客服 | ✅ | ✅ |
| 账号注销 | ✅ | 🚧 |
| AI 超强去水印开关、文档水印文字提示词 | ✅ | 🚧 |

## 技术栈

**Android**

- Kotlin 2.2.20 / AGP 8.13.2 / Gradle Version Catalog
- Jetpack Compose + Material 3，单 Activity、单 ViewModel
- OkHttp（自定义 `RequestBody` 实现**上传进度**，32 KB 缓冲、全程不占内存）
- Coil（图片预览）、ZXing（支付二维码本地生成）
- MediaStore 事务式写入（`IS_PENDING`），兼容 Android 10 前后两套存储模型
- minSdk 24 / targetSdk 36

**iOS**

- SwiftUI，target iOS 17
- XcodeGen 描述工程（`project.yml`），不提交二进制 `.xcodeproj`
- `URLSession` + 手写 multipart、`PhotosPicker` / `fileImporter`
- StoreKit 2 内购（符合 App Store 3.1.1）
- 无第三方依赖

## 快速开始

### Android

环境：JDK 17+、Android SDK Platform 36。

```bash
cd Android
gradle wrapper --gradle-version 8.13   # 首次运行，生成本地 Wrapper
./gradlew :app:assembleDebug
```

产物：`Android/app/build/outputs/apk/debug/app-debug.apk`

### iOS

环境：macOS + Xcode 15 以上。

```bash
brew install xcodegen
cd iOS
xcodegen generate
open AllClear.xcodeproj
```

命令行一键编译并跑模拟器：

```bash
bash iOS/scripts/run_sim.sh "iPhone 16 Pro"
```

### 接口地址

默认连线上环境 `https://allclearwatermark.com/api`。

- Android：`gradle :app:assembleDebug -PapiBase=http://10.0.2.2:8000/api`
- iOS：改 `iOS/AllClear/Services/APIClient.swift` 里的 `baseURL`

如果你 fork 后想接自己的后端，改这两处即可，其余代码无需改动。

## 架构设计

```
┌─────────────┐   ┌─────────────┐
│   Android   │   │     iOS     │
│  Compose    │   │   SwiftUI   │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └───────┬─────────┘
               ▼
    ┌──────────────────────┐
    │  FastAPI 后端（闭源） │
    │  鉴权 / 扣次 / 算法    │
    └──────────────────────┘
```

两端结构保持一致：**无状态 UI → 单一状态中枢 → 数据层**，单向数据流。

- Android 详细架构、取舍与已知不足：[`Android/架构说明.md`](Android/架构说明.md)
- iOS 构建与模拟器调试、远程 Mac / CI 方案：[`iOS/构建与模拟器指南.md`](iOS/构建与模拟器指南.md)

## 常见问题

**Q：后端为什么不开源？**
算法与算力调度是产品的核心成本所在。仓库只包含客户端，接口契约在 `Android/app/src/main/java/com/wuyong/allclear/data/Api.kt` 与 `iOS/AllClear/Services/APIClient.swift` 中完整可见，可据此自行实现服务端。

**Q：编译后能直接用吗？**
可以，客户端默认连接线上服务，注册即送体验次数。但请勿用脚本批量注册——服务端有 IP 频率限制。

**Q：为什么 iOS 不提交 `.xcodeproj`？**
工程文件是二进制化的文本，多人协作时冲突几乎无法合并。用一份可读的 `project.yml` + `xcodegen generate`，任何人（包括 AI Agent）都能秒建工程。

## 免责声明

本项目仅用于**处理你拥有合法权利或已获授权**的素材。请勿用于去除他人享有著作权的作品上的保护性水印并用于商业牟利。因使用本软件产生的任何版权纠纷与法律责任，由使用者自行承担。

## License

[MIT](LICENSE) © 2026 马鞍山市雨山区悟用网络科技工作室

> 本项目采用 MIT 协议开源代码，但**不授予「AllClear」「水印天敌」名称与标识的商标使用权**。二次分发请使用你自己的应用名与图标。
