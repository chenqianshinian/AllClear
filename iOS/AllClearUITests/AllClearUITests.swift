import XCTest

final class AllClearUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // 自动处理相册/相机等系统权限弹窗（模拟器首次运行时会出现）
        addUIInterruptionMonitor(withDescription: "系统权限弹窗") { alert in
            for label in ["允许", "Allow", "允许添加", "好", "OK"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    private func launch(_ extra: [String] = [], reset: Bool = true) {
        app.launchArguments = ["-skipOnboarding"] + (reset ? ["-resetSession"] : []) + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["水印天敌"].waitForExistence(timeout: 20), "主界面未启动")
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openProfile() {
        let tab = app.buttons["tab.mine"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.buttons["login.entry"].waitForExistence(timeout: 10), "我的页面未展示登录入口")
    }

    private func registerAndLogin(prefix: String) {
        let email = "\(prefix).\(Int(Date().timeIntervalSince1970))@wuyongtest.com"
        let password = "AllClear123"

        app.buttons["login.entry"].tap()
        let emailField = app.textFields["login.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "登录弹窗未出现")

        // 切到注册
        app.buttons["login.toggle"].tap()
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["login.password"]
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons["login.submit"].tap()

        // 注册成功后自动回到登录态，再输入一次密码登录
        XCTAssertTrue(app.staticTexts["登录账号"].waitForExistence(timeout: 30), "注册未成功")
        let loginSubmit = app.buttons["login.submit"]
        XCTAssertTrue(loginSubmit.waitForExistence(timeout: 10))
        let field = app.secureTextFields["login.password"]
        if field.exists {
            field.tap()
            field.typeText(password)
        }
        loginSubmit.tap()

        XCTAssertTrue(app.staticTexts["剩余可用次数"].waitForExistence(timeout: 30), "登录未成功")
        snap("02-登录后-我的")
    }

    /// 覆盖：首启 Splash → 隐私弹窗 → 同意进入主界面
    func test00Onboarding() throws {
        app.launchArguments = ["-resetOnboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["服务协议与隐私政策"].waitForExistence(timeout: 15), "首启隐私弹窗未出现")
        snap("00-首启隐私弹窗")
        app.buttons["同意并继续"].tap()
        XCTAssertTrue(app.staticTexts["水印天敌"].waitForExistence(timeout: 10), "同意后未进入主界面")
        snap("00-同意后主界面")
    }

    /// 覆盖：主界面、我的、登录/注册弹窗
    func test01ProfileAndLoginUI() throws {
        launch()
        snap("01-主界面")

        app.buttons["tab.mine"].tap()
        snap("01-我的-未登录")

        app.buttons["login.entry"].tap()
        XCTAssertTrue(app.textFields["login.email"].waitForExistence(timeout: 10))
        snap("01-登录弹窗")
    }

    /// 覆盖：注册/登录 → 选中 demo 图 → 去水印 → 结果展示
    func test02ImageRemoval() throws {
        launch(["-demoImage"])

        openProfile()
        registerAndLogin(prefix: "ios.uitest")

        app.buttons["tab.remove"].tap()
        XCTAssertTrue(app.buttons["remove.process"].waitForExistence(timeout: 10))
        snap("03-已选择图片")

        let process = app.buttons["remove.process"]
        XCTAssertTrue(process.waitForExistence(timeout: 10))
        process.tap()

        let confirm = app.alerts.buttons["确定"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "扣费确认弹窗未出现")
        snap("03-扣费确认")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["处理结果"].waitForExistence(timeout: 180), "去水印结果未返回")
        sleep(1)
        app.swipeUp()
        sleep(1)
        snap("04-处理结果")
        let save = app.buttons["remove.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "未找到保存按钮")

        // 首次保存会触发相册“仅添加”权限弹窗；轮询同时处理权限弹窗与结果 Toast
        save.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var saveSucceeded = false
        var saveFailure: [String] = []
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
            if labels.contains("已全部保存到相册") {
                saveSucceeded = true
                break
            }
            let errors = labels.filter {
                $0.contains("保存失败") || $0.contains("权限") || $0.contains("部分或全部")
            }
            if !errors.isEmpty {
                saveFailure = errors
                break
            }

            var tappedPermission = false
            for label in ["允许", "Allow", "允许添加"] {
                let springboardButton = springboard.buttons[label]
                if springboardButton.exists {
                    springboardButton.tap()
                    tappedPermission = true
                    break
                }
                let alertButton = springboard.alerts.buttons[label]
                if alertButton.exists {
                    alertButton.tap()
                    tappedPermission = true
                    break
                }
            }
            if tappedPermission { continue }
            usleep(300_000)
        }
        XCTAssertTrue(saveSucceeded, "保存到相册失败: \(saveFailure)")
        snap("04b-保存成功")
    }


    /// 覆盖：文档（PDF）去水印流程
    func test04DocumentFlow() throws {
        launch()
        openProfile()
        registerAndLogin(prefix: "ios.doc")

        app.terminate()
        app.launchArguments = ["-skipOnboarding", "-demoDocument"]
        app.launch()

        XCTAssertTrue(app.buttons["remove.process"].waitForExistence(timeout: 20), "文档页未就绪")
        snap("06-文档已选择")

        app.buttons["remove.process"].tap()
        XCTAssertTrue(app.staticTexts["文档处理完成"].waitForExistence(timeout: 240), "文档处理未返回")
        sleep(1)
        app.swipeUp()
        sleep(1)
        snap("07-文档处理结果")
        let save = app.buttons["remove.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "未找到文档分享按钮")

        // 文档流程：下载结果并拉起系统分享面板
        save.tap()
        sleep(4)
        snap("07b-文档分享面板")
        let shareSheet = app.otherElements["ActivityListView"]
        let closeButton = app.buttons["关闭"]
        if closeButton.waitForExistence(timeout: 5) {
            closeButton.tap()
        } else if shareSheet.waitForExistence(timeout: 3) {
            app.swipeDown()
        }
    }

    /// 覆盖：视频框选 → 处理 → 结果预览
    func test05VideoFlow() throws {
        launch()
        openProfile()
        registerAndLogin(prefix: "ios.video")

        app.terminate()
        app.launchArguments = ["-skipOnboarding", "-demoVideo"]
        app.launch()

        XCTAssertTrue(app.staticTexts["框选视频水印"].waitForExistence(timeout: 25), "视频框选页未打开")
        snap("08-视频框选页")

        // 在视频画面上拖动框选水印区域
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.37))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.47))
        start.press(forDuration: 0.15, thenDragTo: end)
        sleep(1)
        snap("09-已框选水印")

        let confirm = app.buttons["video.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["处理完成"].waitForExistence(timeout: 300), "视频处理未返回")
        sleep(1)
        snap("10-视频处理结果")
        let save = app.buttons["保存到相册"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "未找到视频保存按钮")

        save.tap()
        XCTAssertTrue(app.staticTexts["已保存到相册"].waitForExistence(timeout: 180), "视频保存到相册失败")
        snap("11-视频保存成功")
    }

    private func fetchScanSceneId() async throws -> String {
        let url = URL(string: "https://allclearwatermark.com/api/auth/scan/generate")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["scene_id"] as? String ?? ""
    }

    /// 覆盖：扫码登录电脑版页面（相机不可用时回落到相册二维码）
    @MainActor
    func test06ScanPage() async throws {
        let sceneId = try await fetchScanSceneId()
        XCTAssertFalse(sceneId.isEmpty, "无法生成扫码登录 scene_id")

        launch(["-demoScanQR", "allclear_login:\(sceneId)"], reset: false)

        if app.buttons["login.entry"].exists {
            openProfile()
            registerAndLogin(prefix: "ios.scan")
        } else {
            let tab = app.buttons["tab.mine"]
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
        }

        let row = app.staticTexts["扫码登录电脑版"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "扫码登录入口未出现")
        row.tap()

        let albumButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "从相册选择二维码")).firstMatch
        XCTAssertTrue(albumButton.waitForExistence(timeout: 10), "扫码页未打开")
        snap("12-扫码登录页")

        // DEBUG 启动参数注入二维码内容，覆盖 /auth/scan/confirm 全链路
        XCTAssertTrue(app.staticTexts["电脑端已成功登录！"].waitForExistence(timeout: 30), "电脑端确认失败")
        snap("12c-扫码登录成功")
    }

    /// 覆盖：充值中心页面
    func test03RechargePage() throws {
        launch()
        openProfile()
        let recharge = app.buttons["mine.recharge"]
        XCTAssertTrue(recharge.waitForExistence(timeout: 10))
        recharge.tap()
        XCTAssertTrue(app.staticTexts["全网最低价"].waitForExistence(timeout: 15), "充值页未打开")
        snap("05-充值中心")
        XCTAssertTrue(app.buttons["recharge.pay"].waitForExistence(timeout: 10))
    }
}
