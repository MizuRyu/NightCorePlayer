import XCTest

/// デモ録画用のUIテスト。scripts/record-demo.sh から -only-testing で実行される。
/// 通常のテスト実行（make test / CI）からは除外されている（スキーム側で skipped）。
final class DemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoScenario() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-DEMO"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        attachScreenshot(app, name: "01-launch")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
