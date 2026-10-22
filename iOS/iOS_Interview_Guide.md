# 水印天敌 iOS 原生开发 · 技术栈与面试文案

> 项目：AllClear-水印天敌（一云多端 AI 去水印产品，鸿蒙端已上架）
> 本文用途：iOS 开发面试、简历项目描述、作品集讲解、技术深挖准备
> 说明：文中把“项目真实实现”“后端/外部能力”“可延伸但未实现”分开标注，避免面试时把边界说错。

---

## 0. 先背这一段：30 秒项目介绍

> 我负责「水印天敌」iOS 原生端，这是一个一云多端的 AI 去水印产品，鸿蒙端已经上架。iOS 端用 SwiftUI 从零实现，按鸿蒙端的页面结构、Tailwind 视觉规范和后端字段做了 1:1 对齐。核心能力包括图片/PDF/Word/PPT 去水印、视频手动框选后云端处理、结果预览与保存相册、登录注册、扫码登录电脑版和 StoreKit 2 内购。工程零第三方 Swift 依赖，用 XcodeGen 管理工程，用 XCTest + XCUITest 覆盖 7 条端到端 UI 链路和 1 个单测，在 iPhone 17 Pro 模拟器上全部跑通。

**关键词**：SwiftUI、Swift Concurrency、URLSession、multipart 流式上传、TaskGroup、AVFoundation、PhotosUI、StoreKit 2、XCTest/XCUITest、XcodeGen、零三方依赖。

---

## 1. 业务与技术边界（面试先说实话）

### 1.1 iOS 端负责什么

- 素材采集：相册图片/视频、系统文件（PDF/Word/PPT）、相机扫码。
- 交互：图片多选与预览、视频手动框选、扣费确认、进度展示、结果预览、失败重试。
- 网络：登录/注册、用户信息、上传文件、轮询/等待结果、下载结果。
- 媒体：图片转 JPEG、视频尺寸读取、保存到相册、系统分享。
- 账号：JWT 登录态、用户缓存、头像/昵称修改、退出登录。
- 商业化：StoreKit 2 消耗型内购、审核模式、客服兜底。
- 质量：单元测试、UI 自动化、模拟器验收、Release 构建。

### 1.2 服务端负责什么（不要说成端上 AI）

- FastAPI + JWT 鉴权、用户/次数/订单。
- OpenCV 图像修复、PyMuPDF/pptx 文档处理、moviepy 视频逐帧处理。
- AI 图片编辑：SiliconFlow / Qwen-Image-Edit（服务端调用）。
- 文件“阅后即焚”、静态结果文件、扫码登录会话。

### 1.3 项目没有用什么（避免被追问翻车）

- 没有 Core ML / Vision 端侧模型，没有端侧去水印算法。
- 没有 Alamofire、SnapKit、RxSwift、Kingfisher、SDWebImage 等第三方库。
- 没有 Core Data / SwiftData / Realm，用户信息用 UserDefaults 缓存。
- 没有 Keychain（当前 token 存 UserDefaults，这是明确的改进项）。
- 没有完整深色模式、Dynamic Type、VoiceOver 全量适配。
- 没有 CI/CD、崩溃监控、埋点、推送、离线队列。
- 没有自研视频编解码，视频处理在云端。

---

## 2. 技术栈总览

| 分层 | 技术 / 框架 | 在本项目中的用途 | 面试关键词 |
| --- | --- | --- | --- |
| 语言 | Swift 5.9 语言模式（Xcode 26.6 / Swift 6.3 编译器） | 全部业务代码 | Swift 5.9、协议、泛型、Codable、错误处理 |
| UI | SwiftUI | 全部页面、弹窗、导航、动画 | 声明式 UI、状态驱动、组合式布局 |
| UI 互操作 | UIKit / UIViewControllerRepresentable | 分享面板、AVPlayerViewController、相机预览 | SwiftUI ↔ UIKit 互操作 |
| 布局 | SwiftUI `Layout` 协议 | 自实现居中 flex-wrap 图片网格 | 自定义 Layout、sizeThatFits/placeSubviews |
| 并发 | async/await、Task、TaskGroup、@MainActor | 网络请求、并行上传、UI 状态更新 | 结构化并发、Actor 隔离、任务组 |
| 状态 | ObservableObject / @Published / @State / @AppStorage | 登录态、Toast、Loading、导航、偏好 | 单向数据流、轻量 MVVM |
| 网络 | URLSession（data/download/upload） | REST、文件上传、结果下载 | URLSession、multipart、超时、错误映射 |
| 上传 | 自实现 multipart + FileHandle 流式写盘 | 大视频不爆内存 | 流式上传、O(1) 内存、进度回调 |
| 序列化 | Codable + JSONDecoder(.convertFromSnakeCase) + JSONSerialization | 后端 snake_case、动态错误 detail | 编解码、兼容字段、错误体解析 |
| 图片 | PhotosUI、UIImage、UniformTypeIdentifiers | 选图、预览、JPEG 压缩、文件类型 | PhotosPicker、Transferable、UTType |
| 视频 | AVFoundation、AVKit | 读取视频尺寸、播放、循环、框选 | AVAsset、preferredTransform、AVPlayer |
| 相册 | Photos（PHPhotoLibrary / PHAssetCreationRequest） | 保存图片/视频到相册 | 权限、addOnly、资源写入 |
| 二维码 | AVFoundation + CoreImage CIDetector | 相机扫码、相册二维码识别 | AVCaptureSession、MetadataOutput、CIDetector |
| 支付 | StoreKit 2 + `.storekit` 本地配置 | 消耗型内购、价格展示、交易验签 | Product、purchase、VerificationResult、JWS |
| 存储 | UserDefaults / @AppStorage / 临时目录 | token、用户缓存、上传/结果临时文件 | 轻量持久化、沙盒、临时文件 |
| 测试 | XCTest、XCUITest | 单元测试 + 7 条 UI 端到端 | 可测性、无障碍标识、启动参数 |
| 工程 | XcodeGen、xcodebuild、Scheme、Asset Catalog | 工程生成、构建、StoreKit 配置、AppIcon | 工程化、可复现构建 |
| 工具 | xcrun simctl、xcresulttool、plutil、sips、ffmpeg、PIL | 模拟器验收、截图导出、演示素材 | 模拟器自动化、验收资产 |

---

## 3. 架构设计

### 3.1 分层

```text
Views（SwiftUI 页面 / 组件）
   │  @State / @ObservedObject
   ▼
App Services（Session / AppState / Toast / LoadingCenter / StoreManager）
   │
   ▼
APIClient（REST 契约、鉴权、错误映射）
   │
   ├── Uploader（multipart 流式编码 + 进度）
   ├── MediaSaver（下载 / 相册 / 分享）
   └── Models（Codable）
   │
   ▼
FastAPI 后端（JWT / OpenCV / PyMuPDF / moviepy / AI）
```

### 3.2 目录结构

```text
AllClear/
├── AllClearApp.swift
├── Models/Models.swift              # 用户、结果、文件类型、路由
├── Services/
│   ├── APIClient.swift              # 登录、用户、去水印、扫码
│   ├── Uploader.swift               # multipart + 进度
│   ├── Session.swift                # 登录态 / 用户缓存
│   ├── MediaSaver.swift             # 下载 / 保存相册
│   ├── StoreManager.swift           # StoreKit 2
│   └── Toast.swift                  # Toast / Loading
└── Views/
    ├── RootView.swift               # 自定义 TabBar + NavigationStack
    ├── RemoveWatermarkView.swift    # 去水印主页面
    ├── VideoEditView.swift          # 视频框选
    ├── MineView.swift               # 我的
    ├── RechargeView.swift           # 充值中心
    ├── ScanLoginView.swift          # 扫码登录
    ├── LoginSheet.swift             # 登录/注册弹窗
    ├── Components.swift             # 通用组件 / Layout / 播放器
    └── Theme.swift                  # 设计 token
```

### 3.3 状态与导航

- `Session`：全局登录态、用户信息、次数、会员、`inReview` 配置；启动/切到我的页时刷新；401 自动登出。
- `AppState`：当前 Tab、两个 `NavigationStack` 的 path（`[AppRoute]`），用于自定义 TabBar 和页面跳转。
- `Toast` / `LoadingCenter`：全局轻提示与 loading，根视图统一挂载。
- `StoreManager`：StoreKit 商品加载、购买、验签、完成交易。
- 页面内 `@State`：列表、进度、选择、结果、弹窗等局部状态，避免过度全局化。

> 面试话术：不是“为了 MVVM 而 MVVM”，而是按“页面局部状态 + 跨页面服务”拆分；网络/媒体/支付各自独立 Service，页面只关心状态和交互，方便单测和替换。

---

## 4. 核心技术点（含面试话术）

### 4.1 SwiftUI 复刻鸿蒙端 Tailwind 视觉

**场景**：鸿蒙端是 Taro + Tailwind，iOS 要做到“看起来是同一个产品”。

**实现**：
- 把 Tailwind 的颜色、字号、间距、圆角抽成 `ACColor` / `acCard` / `DashedRoundedBorder` / `ACBlueHeader` 等 token 和组件。
- 主色 `#3B82F6`、深蓝 `#2563EB`、灰阶 `#F3F4F6 / #E5E7EB / #9CA3AF` 等逐项对齐。
- 蓝色圆角头图 + 负 `padding` 实现卡片上浮（`padding(.top, -64)`）。
- `UnevenRoundedRectangle` 实现只圆底部的头图。
- 自定义 TabBar 替代系统 TabView，控制白底、顶部细线、选中色、字号。
- 虚线边框用 `strokeBorder` + `StrokeStyle(dash:)`。

**难点**：
- 鸿蒙端是 `min-h-48`、`flex-wrap` 的 Web 布局，SwiftUI 没有直接等价物。
- 卡片圆角裁剪会裁掉头像/删除角标，需要区分“背景裁剪”和“内容溢出”。

**话术**：
> 我不是把设计稿当图片贴上去，而是把鸿蒙端的 Tailwind 语义拆成设计 token 和可复用组件；间距、字号、圆角、阴影都有统一来源，所以后面加页面不会出现“每个页面各写一套”的问题。

---

### 4.2 自定义 `Layout` 实现居中 flex-wrap

**场景**：图片预览区/结果区需要 80×80 缩略图按行排列、每行居中、自动换行，类似 Tailwind 的 `flex flex-wrap gap-2 justify-center`。

**实现**：
- 实现 SwiftUI `Layout` 协议：
  - `sizeThatFits`：按可用宽度贪心分行，计算总高度。
  - `placeSubviews`：每行按剩余宽度居中摆放。
- 支持 `spacing` / `lineSpacing`，图片和“+”号都作为子视图。

**为什么不用 LazyVGrid**：
- `LazyVGrid` 的列宽/对齐控制不如自定义 Layout 精确；鸿蒙端是“每行居中”的 flex-wrap，不是固定网格。
- 自定义 Layout 可复用到图片选择、结果展示、未来其他标签流。

**话术**：
> 这个点能体现我不是只会堆 View。SwiftUI 的 `Layout` 协议让我用声明式方式实现类似 flex-wrap 的布局，行宽、居中、换行都是可计算的，和鸿蒙端的视觉完全一致。

---

### 4.3 大文件上传：multipart 流式写临时文件

**场景**：视频可能接近 100MB，不能把整个 multipart body 拼在内存里。

**实现**：
- `Uploader` 先把 multipart 头、字段、文件内容写入临时文件。
- 文件部分用 `FileHandle` 分块读取（1MB/块）写入 body 文件，内存占用 O(1)。
- 再用 `URLSession.upload(for:fromFile:)` 从文件上传。
- `URLSessionTaskDelegate` 的 `didSendBodyData` 回调上传进度，主线程更新 UI。

**示意**：

```swift
let input = try FileHandle(forReadingFrom: fileURL)
while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
    try bodyHandle.write(contentsOf: chunk)
}
```

**话术**：
> 如果直接 `Data(contentsOf:)` 再拼 multipart，100MB 视频会瞬间让内存翻几倍。我改成“边读边写临时文件 + 文件上传”，内存只跟 1MB 缓冲区有关，上传进度也能通过 URLSession delegate 拿到。

---

### 4.4 结构化并发：TaskGroup 并行上传、按原顺序聚合

**场景**：最多 9 张图片，需要并行上传提高速度，但结果必须按用户选择顺序展示。

**实现**：
- `withTaskGroup(of: (Int, Result<URL, Error>).self)`，每个子任务带原始 index。
- 结果写入 `[URL?]` 的对应下标；进度按完成数量更新“处理中 x/N”。
- 只更新 UI 的代码在 `@MainActor` 上执行；子任务只做网络/文件 IO。
- 第一处错误保存下来，整体抛给页面；页面统一展示额度不足/网络错误。

**话术**：
> 并行上传的关键不是“开 Task”，而是“结果顺序”和“UI 线程安全”。我用 index 绑定任务和结果，子任务不碰 UI，主线程只做状态聚合；这样既快又不会图片顺序乱掉。

---

### 4.5 视频框选：屏幕坐标 → 原始像素坐标

**场景**：用户在手机屏幕上拖框选水印，后端需要原始视频分辨率的 `x/y/width/height`。

**实现**：
- `AVURLAsset.loadTracks(withMediaType: .video)` 读取 `naturalSize` 和 `preferredTransform`，得到显示尺寸（考虑旋转）。
- 视频容器按原始宽高比展示，框选存的是容器内坐标。
- 提交时：
  ```swift
  let scaleX = originalWidth / drawingSize.width
  let scaleY = originalHeight / drawingSize.height
  let region = WatermarkRegion(
      x: Int(rect.minX * scaleX),
      y: Int(rect.minY * scaleY),
      width: Int(rect.width * scaleX),
      height: Int(rect.height * scaleY)
  )
  ```
- 后端 `regions` 直接接收原始像素区域。

**难点**：
- 视频有旋转 metadata，不能只看 `naturalSize`。
- 容器可能因屏幕高度被限制，不能假设“容器宽 = 视频宽”。
- 框选拖动方向可能为负，需要 normalize 成左上角 + 正宽高。

**话术**：
> 这是端云协同里最容易错的地方：用户看到的是缩放后的画面，后端要的是原视频像素。我做了三层处理：读取视频旋转后的显示尺寸、按容器实际尺寸算 scale、把拖动产生的负宽高 normalize。否则框选区域会整体偏移。

---

### 4.6 AVPlayerViewController 的“状态栏消失”坑

**场景**：视频页用 `AVPlayerViewController` 做播放，进入页面后状态栏（时间/电量）消失。

**原因**：
- `AVPlayerViewController` 作为子控制器时可能影响状态栏隐藏/样式。

**解决**：
- 子类化并显式声明：
  ```swift
  private final class StatusBarVisiblePlayerViewController: AVPlayerViewController {
      override var prefersStatusBarHidden: Bool { false }
      override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  }
  ```
- 循环播放用 `AVPlayerItemDidPlayToEndTime` 通知 seek 到 0 再 play。
- 框选页关闭 `showsPlaybackControls`，让手势层接管触摸；结果页打开 controls。

**话术**：
> 这是一个典型的 SwiftUI + UIKit 互操作问题：UI 上看起来是“状态栏没了”，本质是子控制器对状态栏的管理。我用子类显式覆盖，既保留系统播放器能力，又保证页面视觉一致。

---

### 4.7 全屏 cover 下的 Toast 层级与反馈

**场景**：扫码确认成功后，全局 Toast 挂在根视图，但扫码页是 `fullScreenCover`，Toast 被盖住，用户看不到成功反馈。

**解决**：
- 不再依赖根视图 Toast，扫码页内部做“确认中 / 成功 / 失败”三态本地反馈。
- 成功后展示独立的成功页（绿色对勾 + “电脑端已成功登录！”），2 秒后 dismiss。
- 失败显示行内错误，允许再次扫码。

**话术**：
> 这个 bug 让我意识到“全局组件”不是万能的：全屏模态会改变视图层级。我的处理是把反馈收敛到当前模态内部，保证用户一定看得到；同时 UI 测试也能稳定断言。

---

### 4.8 网络层：统一错误映射与契约兼容

**实现**：
- `APIError` 枚举：`unauthorized`、`server(status:message:)`、`transport`、`decoding`、`notLoggedIn`。
- 401：登出并提示重新登录。
- 402/403：额度不足，Toast 停留更久，引导充值/签到。
- 413：文件过大。
- 429：请求过于频繁。
- 5xx/网络错误：统一“网络异常或服务繁忙”。
- `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` 适配后端 `result_url` / `tier_expires_at`。
- 结果 URL 兼容 `result_url` / `output_url` / `url`，并兼容 `/static` 相对路径。
- 上传统一带 `client=miniprogram`，让后端返回 JSON（与鸿蒙端保持一致）。

**话术**：
> 后端错误不是都适合直接抛给用户。我在 APIClient 做了一层“技术错误 → 产品文案”的映射，页面只处理 `APIError`，不需要每个页面都判断 status code。

---

### 4.9 登录态与用户缓存

**实现**：
- 登录成功保存 JWT，`Session` 统一持有 `isLogin` / `user`。
- 启动、切到“我的”页时刷新 `/users/me`。
- 401 自动 logout，避免死循环。
- 用户信息缓存到 UserDefaults，弱网时先展示缓存。
- 昵称为空时用邮箱前缀兜底（与鸿蒙端一致）。
- 头像/昵称修改后更新本地缓存。

**诚实说明**：
- 当前 token 存 UserDefaults，生产环境应迁移 Keychain（可配合 Accessibility/生物识别）。
- 当前没有 refresh token，JWT 过期需要重新登录。

**话术**：
> 这个项目是 MVP 阶段，token 放 UserDefaults 是为了快速联调；如果上线我会迁到 Keychain，并加 refresh token / 静默续期。面试官问安全时，我会主动说这个边界，而不是等他挑。

---

### 4.10 媒体保存与分享

**实现**：
- 结果图片/视频先下载到临时目录，再用 `PHPhotoLibrary.requestAuthorization(for: .addOnly)` 申请“仅添加”权限。
- `PHAssetCreationRequest` + `PHAssetResourceCreationOptions` 写入相册。
- 文档下载后生成 `原名(无水印).ext`，用 `UIActivityViewController` 拉起系统分享/存储到文件。
- 文件名做非法字符过滤；下载失败/权限拒绝都有明确 Toast。
- `fileImporter` 选文档时使用 security-scoped resource，读完立即停止访问。

**话术**：
> 保存相册看似一行 API，实际要处理权限、临时文件、文件名、视频/图片类型、失败提示。我把这些收敛到 `MediaSaver`，页面只关心“保存成功/失败”。

---

### 4.11 扫码登录：相机 + 相册双通道

**实现**：
- 相机：`AVCaptureSession` + `AVCaptureMetadataOutput` 识别 QR，主线程回调。
- 相册：`PhotosPicker` 选图 → `CIDetector` 识别二维码。
- 解析 `allclear_login:<sceneId>` → `POST /auth/scan/confirm`。
- 模拟器/无摄像头自动降级为“从相册选择二维码”，并给出提示。
- 权限被拒绝时显示占位和引导，不崩溃。

**话术**：
> 扫码不是只有相机。模拟器没有摄像头，所以我做了相册识别作为降级路径；这样既方便真机，也能让 UI 自动化在模拟器里跑通。

---

### 4.12 StoreKit 2 内购

**实现**：
- 三个消耗型商品：`pack_10` / `pro_monthly` / `pro_yearly`。
- `Product.products(for:)` 加载商品和本地化价格。
- `product.purchase()` → `VerificationResult` → 取 `jwsRepresentation` 交后端验签 → `transaction.finish()`。
- 未配置商品时显示“支付暂未开通”，引导客服，不静默扣款。
- `AllClear.storekit` + Scheme 的 StoreKit Configuration 支持本地测试。
- 后端 `/orders/apple-iap` 尚未上线，App 会明确提示“服务器暂未开通发货接口”。

**话术**：
> 内购不是前端调个 purchase 就完了，关键是交易验签和幂等发货。我把 JWS 交给后端，后端验签成功才 finish；后端未配置时我会阻止交易闭环并提示客服，避免用户付了钱没到账。

---

### 4.13 测试与可测性

**测试分层**：
- 单元测试：StoreKit 配置结构校验（商品 ID、类型、本地化）。
- UI 测试：7 条端到端链路。
- 截图：XCTAttachment + `xcresulttool export attachments`。

**可测性设计**：
- 关键控件加 `accessibilityIdentifier`（`tab.mine`、`login.email`、`remove.process`、`remove.save`、`recharge.pay`、`video.confirm`）。
- Debug 启动参数：
  - `-skipOnboarding`、`-resetOnboarding`、`-resetSession`
  - `-startTab mine`、`-openRecharge`
  - `-demoImage`、`-demoDocument`、`-demoVideo`
  - `-demoScanQR allclear_login:<scene>`
- UI 测试用 `simctl privacy grant photos-add` 预授权，避免系统弹窗导致 flaky。
- StoreKit 配置在 iOS 26.5 模拟器通过 CLI 不注入，因此单测只做结构校验，真实购买用 Xcode Run 验证。

**踩过的测试坑**：
- 异步 UI 测试里 `XCUIApplication.launch()` 必须在主线程 → 测试方法加 `@MainActor`。
- Toast 只有 2 秒，测试要轮询而不是等固定时间。
- 相册权限弹窗可能在 SpringBoard 层，元素查询要兼容 `springboard.buttons` / `springboard.alerts.buttons`。
- 全屏 cover 会盖住全局 Toast，测试断言要基于页面内反馈。

**话术**：
> 我做 UI 测试不是只点按钮，而是把“可测性”反过来设计：控件有稳定 id、调试态可注入数据、权限可预授权、结果有明确文案。这样测试才能稳定跑在 CI 上。

---

### 4.14 工程化：零三方依赖 + XcodeGen + 多 Target

**实现**：
- `project.yml` 定义 App、Unit Tests、UI Tests 三个 Target。
- `sources` 自动收集文件；`info.properties` 统一维护 Info.plist 权限文案。
- Scheme 配置 StoreKit Configuration、Test Target。
- `AllClear.storekit`、`Assets.xcassets/AppIcon`、`demo_*` 资源。
- `xcodebuild build` / `test` 可复现；Release 构建通过。
- 零第三方 Swift 依赖，减少供应链和包管理成本。

**话术**：
> 我用 XcodeGen 把工程配置代码化，新增文件不需要手动拖进 Xcode；Info.plist 权限、Scheme、测试 Target、StoreKit 配置都在 `project.yml` 里可追溯。对团队协作和 CI 都更友好。

---

## 5. 关键流程时序

### 5.1 图片去水印

```text
用户选图（PhotosPicker）
  → 转 JPEG / 校验大小
  → 扣费确认（UI 按 1 次/张、AI 5 次/张展示，实际计费以接口为准）
  → TaskGroup 并行 POST /remove-image-watermark
  → 后端返回 result_url
  → 并行下载预览（失败回落远程 URL）
  → 结果网格 / 全屏预览
  → 保存全部到相册（PHPhotoLibrary）
```

### 5.2 PDF 去水印

```text
fileImporter 选 PDF
  → security-scoped access + 复制到沙盒
  → POST /remove-pdf-watermark（client=miniprogram）
  → 返回 result_url
  → 文档完成卡片
  → 下载为“原名(无水印).pdf”
  → UIActivityViewController 打开/分享
```

### 5.3 视频去水印

```text
PhotosPicker 选视频（Transferable 拷贝到沙盒）
  → AVAsset 读取旋转后尺寸
  → 用户拖拽框选（容器坐标）
  → scaleX/scaleY 映射到原始像素
  → POST /remove-video-watermark（regions JSON）
  → 返回 result_url
  → AVPlayer 预览
  → 保存到相册 / 重新框选
```

### 5.4 扫码登录

```text
相机 MetadataOutput / 相册 CIDetector
  → 解析 allclear_login:<sceneId>
  → POST /auth/scan/confirm（Bearer token）
  → 成功页“电脑端已成功登录！”
  → 2 秒后关闭
```

---

## 6. 工程质量与边界

### 6.1 已验证

- iPhone 17 Pro / iOS 26.5 模拟器：Debug、Release 构建通过。
- 1 个单元测试 + 7 个 UI 测试全部通过。
- 图片、PDF、文档分享、视频框选/处理/保存、扫码登录均端到端跑通。
- 19 张验收截图（`ios/Screenshots/`）。
- 零第三方 Swift 依赖。

### 6.2 已知不足（面试主动说，反而加分）

| 项 | 现状 | 改进 |
| --- | --- | --- |
| Token 存储 | UserDefaults | 迁移 Keychain + refresh token |
| 临时文件 | 沙盒 tmp，依赖系统清理 | 保存/分享后主动删除，兑现“阅后即焚” |
| 网络韧性 | 无重试/退避/弱网监听 | 增加 retry、timeout、NWPathMonitor |
| 离线能力 | 仅用户信息缓存 | 任务队列、断点续传、离线草稿 |
| 深色模式 | 按浅色视觉设计 | 语义色 + 深色配色 |
| Dynamic Type | 固定字号 | `ScaledMetric` / 动态字体 |
| 无障碍 | 仅测试 id | VoiceOver 标签、对比度、焦点顺序 |
| 国际化 | 中文硬编码 | String Catalog |
| 监控 | 无 | 崩溃、网络、上传成功率埋点 |
| CI/CD | 本机 xcodebuild | GitHub Actions / Fastlane + 模拟器矩阵 |
| 内购 | StoreKit 本地配置 | App Store Connect 商品 + 后端 apple-iap |
| 测试环境 | 直连生产 API | Mock/Staging + 固定测试账号 |

---

## 7. 面试文案

### 7.1 简历项目描述（5 条，可直接用）

- 负责「水印天敌」iOS 原生端从 0 到 1，使用 SwiftUI 复刻鸿蒙端页面与交互，覆盖图片/视频/PDF/Word/PPT 去水印、结果预览、保存相册、登录注册、扫码登录、StoreKit 2 内购。
- 设计分层架构：Views + App Services + APIClient/Uploader/MediaSaver + Codable Models；零第三方 Swift 依赖，XcodeGen 管理多 Target 工程。
- 实现大文件 multipart 流式上传：FileHandle 分块写临时文件 + `URLSession.upload(fromFile:)`，将 100MB 级视频上传的内存占用控制在常量级，并通过 URLSessionTaskDelegate 回传进度。
- 使用 Swift Concurrency（async/await、TaskGroup、@MainActor）实现 9 图并行上传与顺序聚合；完成视频框选坐标到原始像素的映射，解决 AVPlayerViewController 状态栏、全屏模态 Toast 层级等 SwiftUI/UIKit 互操作问题。
- 搭建 XCTest + XCUITest 验收体系：7 条端到端 UI 测试 + StoreKit 配置单测，配合 Debug 启动参数、演示素材、权限预授权，在 iPhone 17 Pro 模拟器全部跑通。

### 7.2 简历项目描述（3 条精简版）

- SwiftUI 从 0 到 1 实现「水印天敌」iOS 端，按鸿蒙端 Tailwind 规范复刻页面与交互，覆盖图片/文档/视频去水印、保存相册、登录、扫码、StoreKit 内购。
- 自实现 multipart 流式上传与 TaskGroup 并行任务，解决大视频内存占用和多图结果顺序问题；完成视频框选坐标映射、AVPlayer 状态栏、全屏模态反馈等端云协同/互操作难点。
- 零三方依赖 + XcodeGen 多 Target 工程；XCTest/XCUITest 覆盖 7 条端到端 UI 链路 + StoreKit 配置单测，模拟器验收通过。

### 7.3 2 分钟口述版

> 这个项目是一个一云多端的 AI 去水印产品，鸿蒙端已经上架，我负责 iOS 原生端。业务上用户可以传图片、视频、PDF/Word/PPT，云端做去水印，端上负责采集、框选、上传、进度、结果预览和保存。
>
> 技术上我用 SwiftUI 从零实现，第一件事是把鸿蒙端的 Tailwind 视觉拆成设计 token 和组件，保证两个端看起来是同一个产品。网络层用 URLSession + 自实现 multipart，视频最大接近 100MB，我没有把文件整个读进内存，而是用 FileHandle 分块写临时文件，再用 upload(fromFile:) 上传，内存只跟 1MB 缓冲区有关。
>
> 图片最多 9 张，我用 TaskGroup 并行上传，用 index 绑定结果保证顺序；UI 更新全部回到 MainActor。视频这块比较有挑战：用户在缩放后的画面上框选，后端要原始像素，我读取 AVAsset 的 naturalSize 和 preferredTransform，按容器实际尺寸算 scale，把框选坐标映射回原视频；同时处理了旋转、负宽高、容器高度限制。
>
> 还踩过两个典型的互操作坑：AVPlayerViewController 会让状态栏消失，我通过子类覆盖 prefersStatusBarHidden 解决；扫码页是 fullScreenCover，根视图的 Toast 被盖住，我把成功/失败反馈收敛到模态内部。
>
> 工程上零第三方依赖，用 XcodeGen 管理 App、单测、UI 测试三个 Target；测试用 accessibilityIdentifier、Debug 启动参数、演示素材和 simctl 权限预授权，7 条 UI 测试在 iPhone 17 Pro 模拟器全部通过。内购用 StoreKit 2，后端 apple-iap 还在补，所以我会明确提示用户而不是静默扣款。

### 7.4 STAR 案例

#### 案例 A：100MB 视频上传内存优化

- **S**：视频最大接近 100MB，最初把 `Data` 拼 multipart，内存峰值高，低端机有被杀风险。
- **T**：在不引入第三方库的前提下，把上传内存降到常量级，并保留进度。
- **A**：自实现 multipart 编码；文件部分用 `FileHandle` 1MB 分块写入临时文件；用 `URLSession.upload(for:fromFile:)`；`URLSessionTaskDelegate` 回传进度；主线程更新 UI。
- **R**：内存占用从“文件大小量级”降到“1MB 缓冲 + 元数据”；上传进度可用；代码零依赖、可复用。

#### 案例 B：视频框选坐标偏移

- **S**：用户框选区域上传后，后端去除的位置整体偏移，尤其是竖屏/旋转视频。
- **T**：让端上框选坐标准确映射到原视频像素。
- **A**：读取 `naturalSize` + `preferredTransform` 得到显示尺寸；按容器实际尺寸计算 scaleX/scaleY；normalize 负宽高；提交前 round 成 Int。
- **R**：框选区域与视频水印位置对齐；支持不同分辨率/旋转视频。

#### 案例 C：全屏模态下反馈丢失

- **S**：扫码确认成功，用户看不到任何反馈，测试也断言不到 Toast。
- **T**：保证全屏模态内的成功/失败反馈可见、可测。
- **A**：分析视图层级，确认根视图 Toast 被 fullScreenCover 覆盖；改为模态内部三态（确认中/成功/失败），成功页 2 秒后 dismiss；UI 测试基于页面内文案断言。
- **R**：用户反馈明确，测试稳定通过；形成“全局组件要考虑模态层级”的经验。

### 7.5 作品集 / 项目介绍文案（100–200 字）

> 「水印天敌」iOS 端是一款 AI 去水印工具的原生实现，支持图片、视频、PDF/Word/PPT 的去水印处理。我使用 SwiftUI 完成全部页面与交互，按鸿蒙端 Tailwind 规范做视觉对齐；网络层自实现 multipart 流式上传与 TaskGroup 并行任务，解决大文件内存和多图顺序问题；视频侧完成框选坐标到原始像素的映射，并处理 AVPlayer/全屏模态等互操作细节。工程零第三方依赖，XcodeGen 管理多 Target，XCTest/XCUITest 覆盖 7 条端到端 UI 链路和 1 个 StoreKit 配置单测，并在模拟器跑通。

### 7.6 技术亮点一句话（可挑 3 条说）

1. 零第三方 Swift 依赖，全部基于 Apple 原生框架。
2. 100MB 级视频上传内存常量级：FileHandle 分块 + upload(fromFile:)。
3. TaskGroup 并行上传 + index 聚合，兼顾速度与结果顺序。
4. 视频框选坐标映射：naturalSize + preferredTransform + scale。
5. SwiftUI `Layout` 协议自实现居中 flex-wrap。
6. AVPlayerViewController 状态栏/全屏 Toast 层级等互操作问题的定位与修复。
7. StoreKit 2 JWS 交后端验签，未配置发货时阻止交易闭环。
8. 可测性设计：accessibilityIdentifier + Debug 启动参数 + 演示素材 + 权限预授权。
9. XcodeGen 工程代码化，多 Target 可复现构建。
10. 端云职责边界清晰：端上不跑模型，负责采集/框选/上传/预览/保存。

---

## 8. 高频面试题与参考回答

### Q1：为什么选 SwiftUI，而不是 UIKit？

> 这个项目页面结构清晰、状态驱动明显，SwiftUI 的开发效率和可维护性更高；同时我用 UIKit 互操作补齐了分享面板、AVPlayerViewController、相机预览这些 SwiftUI 还不擅长的部分。选型不是“SwiftUI 万能”，而是“SwiftUI 为主 + UIKit 补位”。

### Q2：为什么零第三方依赖？

> 项目用到的能力（网络、图片、视频、相册、二维码、支付）Apple 原生框架都能覆盖；零依赖减少供应链风险、包管理成本和审核不确定性。代价是 multipart、图片缓存等要自己写，但这也让我对底层更熟。

### Q3：怎么保证和鸿蒙端一致？

> 三个层面：视觉上把 Tailwind 的颜色/字号/间距/圆角抽成 token；交互上按鸿蒙端页面状态机复刻（tab 切换确认、扣费确认、处理进度、文档重试）；接口上直接对齐鸿蒙端的单文件接口和表单字段（regions/use_ai/prompt/client=miniprogram），而不是自己另起一套 batch 协议。

### Q4：100MB 视频怎么上传？

> 不把文件读成一个大 Data。自实现 multipart，文件部分用 FileHandle 1MB 分块写入临时文件，再用 URLSession.upload(fromFile:) 上传；进度通过 URLSessionTaskDelegate 的 didSendBodyData 回传。内存占用是常量级，不是文件大小级。

### Q5：多图并行上传，怎么保证顺序？

> TaskGroup 的子任务返回 `(index, Result<URL, Error>)`，结果写入对应下标的数组；完成顺序不影响最终展示顺序。UI 更新统一回 MainActor，子任务不碰 UI。

### Q6：视频框选坐标怎么映射？

> 读取 AVAsset 的 naturalSize 和 preferredTransform 得到显示尺寸；按视频容器的实际宽高算 scaleX/scaleY；把框选的 minX/minY/width/height 乘 scale；负宽高先 normalize；最后 round 成 Int 传给后端。

### Q7：Token 为什么放 UserDefaults？安全吗？

> 这是 MVP 阶段的取舍，UserDefaults 方便联调；生产我会迁 Keychain，并加 refresh token/静默续期。面试官如果问安全，我会主动说明这个边界，而不是把它说成最佳实践。

### Q8：怎么处理 401 / 额度不足 / 文件过大？

> APIClient 统一映射：401 清登录态并提示重新登录；402/403 提示额度不足并引导充值；413 提示文件过大；429 提示频繁；5xx/网络错误统一“网络异常或服务繁忙”。页面只处理 APIError，不重复判断 status code。

### Q9：怎么测试内购和系统权限？

> 内购用 `.storekit` 本地配置 + StoreKit 2；iOS 26.5 模拟器通过 CLI 不注入 Scheme 配置，所以真实购买用 Xcode Run 验证，单测做配置结构校验。权限用 `simctl privacy grant photos-add` 预授权；UI 测试里也兼容 SpringBoard 弹窗。

### Q10：最难排查的 bug 是什么？

> 两个：一是 AVPlayerViewController 导致状态栏消失，表面看是 UI 问题，实际是子控制器状态栏管理，最后用子类覆盖解决；二是扫码成功 Toast 被 fullScreenCover 盖住，用户完全看不到反馈，最后把反馈收敛到模态内部。共同经验是：先搞清楚视图/控制器层级，再改代码。

### Q11：如果后端接口变了，怎么兼容？

> 结果 URL 同时兼容 result_url/output_url/url；相对路径统一拼绝对地址；Codable 用 convertFromSnakeCase；错误体同时解析 detail/message；新字段用可选值，避免旧后端缺字段导致解码失败。契约变更优先在 APIClient 层消化，不扩散到页面。

### Q12：弱网/离线怎么优化？

> 当前只有用户信息缓存。后续会加：请求超时/重试/指数退避、NWPathMonitor 网络状态、上传断点续传、任务队列、失败草稿、结果本地缓存。视频上传是最需要断点续传的场景。

### Q13：如果要在端上做 AI 去水印，怎么做？

> 可以把轻量分割/检测模型转 Core ML，用 Vision 做预处理，端上只做水印区域检测和 mask，生成/修复仍可放云端；或者用 Core ML 的 image inpainting 小模型做离线兜底。当前项目端上不跑模型，这是明确边界。

### Q14：如何提升图片列表性能？

> 缩略图降采样（ImageIO `CGImageSourceCreateThumbnailAtIndex`）、避免主线程解码、列表用 Lazy 容器、限制并发解码、缓存 NSCache；当前 9 张图规模不需要，但用户量/数量上来要补。

### Q15：为什么不用 Core Data / SwiftData？

> 当前服务端是唯一数据源，端上只需要登录态和用户信息缓存，UserDefaults 足够；引入数据库会增加迁移和同步成本。如果要做离线任务/历史记录，再引入 SwiftData 更合适。

### Q16：深色模式 / 国际化 / 无障碍怎么做？

> 当前按鸿蒙端浅色视觉固定配色，字号也是固定 pt；后续会把颜色改成语义色、字号用 ScaledMetric/动态字体、文案进 String Catalog、补 VoiceOver 标签和焦点顺序。这些是明确的发布前改进项。

### Q17：怎么保证隐私合规？

> Info.plist 写清相册/相机用途；首启隐私弹窗与用户协议/隐私政策；只申请必要权限；文件走 HTTPS；服务端承诺阅后即焚。端上还可以补：保存/分享后主动删除临时文件、隐私清单 PrivacyInfo.xcprivacy、App 隐私标签。

### Q18：这个项目你最大的收获是什么？

> 一是端云协同的边界感：端上不追着做算法，而是把采集、坐标、上传、进度、预览、保存做到稳定；二是“可测性”要设计出来，不是测试阶段才补；三是遇到 UI 问题先看视图/控制器层级，很多“玄学”其实是层级和生命周期。

### Q19：如果给你更多时间，你先做什么？

> P0：后端 apple-iap + Keychain + 隐私清单 + Staging/Mock + CI；P1：重试/弱网/断点续传、临时文件清理、Dynamic Type/深色/国际化/无障碍；P2：端侧轻量模型、后台上传、推送。

### Q20：你在这个项目里具体写了多少代码？

> 不虚构行数。可以这样说：iOS 端从 0 到 1，包含 4 个主页面 + 视频框选/扫码/充值等页面、网络/上传/媒体/支付/会话服务、设计系统与通用组件、1 个单测 + 7 个 UI 测试。重点不是行数，而是完整链路的交付和可验证性。

---

## 9. 一分钟背诵版

> 我负责「水印天敌」iOS 原生端，SwiftUI 从 0 到 1，按鸿蒙端 Tailwind 规范复刻页面与交互，覆盖图片/视频/PDF/Word/PPT 去水印、保存相册、登录注册、扫码登录和 StoreKit 2 内购。网络层自实现 multipart 流式上传，100MB 级视频用 FileHandle 分块 + upload(fromFile:)，内存常量级；9 图用 TaskGroup 并行上传、index 保证顺序；视频框选用 AVAsset 的 naturalSize/preferredTransform 做坐标映射。工程零三方依赖，XcodeGen 管理多 Target，XCTest/XCUITest 7 条端到端 UI 链路 + 1 个单测在 iPhone 17 Pro 模拟器全部跑通。内购后端发货接口和 Keychain 是明确的发布前改进项。

---

## 10. 术语速查

| 术语 | 一句话解释 |
| --- | --- |
| SwiftUI | Apple 声明式 UI 框架，状态驱动视图 |
| UIKit 互操作 | 通过 `UIViewControllerRepresentable`/`UIViewRepresentable` 在 SwiftUI 中使用 UIKit |
| `Layout` 协议 | SwiftUI 自定义布局协议，实现 sizeThatFits/placeSubviews |
| async/await | Swift 结构化并发语法 |
| TaskGroup | 并发执行一组子任务并聚合结果 |
| @MainActor | 保证代码在主线程/主 Actor 执行 |
| multipart/form-data | HTTP 文件上传格式，含 boundary、字段、文件 part |
| URLSessionTaskDelegate | 获取上传进度等任务回调 |
| AVAsset | 媒体资源抽象，可读取轨道、尺寸、旋转 |
| preferredTransform | 视频旋转/变换信息 |
| PhotosPicker | SwiftUI 相册选择器，返回 Transferable |
| PHPhotoLibrary | 相册读写框架 |
| AVCaptureMetadataOutput | 相机元数据（二维码）识别输出 |
| CIDetector | Core Image 的图像特征检测器，可用于二维码 |
| StoreKit 2 | Apple 新一代内购框架，async/await + VerificationResult |
| JWS | JSON Web Signature，StoreKit 交易凭证 |
| XCUITest | Apple UI 自动化测试框架 |
| accessibilityIdentifier | 给控件设置稳定测试标识 |
| XcodeGen | 用 YAML 生成 Xcode 工程的工具 |
| JWT | JSON Web Token，登录态凭证 |
| ATS | App Transport Security，默认要求 HTTPS |

---

## 11. 最后提醒：面试时的“三说三不说”

**多说**：
- 你真实做过的取舍（零依赖、UserDefaults 的边界、模拟器 StoreKit 限制）。
- 你定位问题的过程（视图层级、控制器生命周期、坐标映射）。
- 你如何验证（8 条测试、截图、Release 构建、模拟器）。

**不要硬说**：
- 不要说“端上跑 AI 模型”（项目没有）。
- 不要说“用了 Alamofire/RxSwift/Kingfisher”（没有）。
- 不要说“已经完整上架/支付闭环”（内购后端未上线）。

把边界说清楚，比把所有技术名词都堆上去更可信。
