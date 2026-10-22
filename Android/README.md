# Android 客户端

Kotlin + Jetpack Compose 实现的去水印客户端，与 [`../iOS`](../iOS) 共用同一套后端 API。

## 技术栈

| 项 | 选型 |
| --- | --- |
| 语言 / 构建 | Kotlin 2.2.20 · AGP 8.13.2 · Gradle Version Catalog |
| UI | Jetpack Compose + Material 3 |
| 状态 | AndroidViewModel + `mutableStateOf`（单 Activity、单 ViewModel）|
| 网络 | OkHttp 4.12 + `org.json`（手写序列化，自定义 `RequestBody` 实现上传进度）|
| 图片 | Coil 2.7 |
| 二维码 | ZXing（本地生成，不联网）|
| SDK | minSdk 24 · targetSdk 36 · compileSdk 36 |

## 目录结构

```
app/src/main/java/com/wuyong/allclear/
├── MainActivity.kt          单 Activity 入口
├── data/                    Api · ApiClient · FileProgressBody · MediaSaver · UserInfo
└── ui/                      MainViewModel · Theme · HomeScreen · MineScreen · Dialogs …
```

## 构建

环境要求：JDK 17+、Android SDK Platform 36。

```bash
cd Android

./gradlew :app:assembleDebug         # macOS / Linux
gradlew.bat :app:assembleDebug       # Windows
```

产物：`app/build/outputs/apk/debug/app-debug.apk`，用调试证书签名，**下载即可安装**。

> 没装 Android Studio 的话，需要先设置环境变量 `ANDROID_HOME`（或写一个 `local.properties` 指向 SDK 目录），
> 否则 Gradle 会报 `SDK location not found`。装了 Android Studio 的直接用它打开本目录，会自动生成 `local.properties`。

### 切换后端地址

```bash
./gradlew :app:assembleDebug -PapiBase=http://10.0.2.2:8000/api
```

默认值在 `data/Api.kt`：`https://allclearwatermark.com/api`。

## 功能

图片多选批量、视频单个、PDF / Word / PPT 文档、上传与处理进度、结果预览 / 保存相册 / 系统分享、邮箱登录注册、每日签到、充值（支付宝 / 微信扫码）、协议与隐私确认、账号注销。

## 架构说明

分层、数据流、关键实现与已知不足见 [架构说明.md](架构说明.md)。
