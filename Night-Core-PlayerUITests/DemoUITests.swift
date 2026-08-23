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

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // 検索タブで検索語を入力（タブ名はローカライズされるためインデックスで選択: 0=Player 1=Search 2=Playlist 3=Settings）
        tabBar.buttons.element(boundBy: 1).tap()
        let searchField = app.textFields["search_field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        attachScreenshot(app, name: "02-search")
        searchField.tap()
        searchField.typeText("Lumen")

        // 結果表示待ち（検索は debounce 500ms）
        let firstSongRow = app.buttons["search_result_song"].firstMatch
        XCTAssertTrue(firstSongRow.waitForExistence(timeout: 10))
        attachScreenshot(app, name: "03-search-results")

        // 曲をタップして再生画面へ
        firstSongRow.tap()
        XCTAssertTrue(app.staticTexts["夜間飛行"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "04-player")

        // 速度ボタンで倍速変更（初期レートは復元値次第なので「表示が変わる」ことだけ見る）
        let speedUpButton = app.buttons["speed_increase_large"]
        XCTAssertTrue(speedUpButton.waitForExistence(timeout: 10))
        let rateLabel = app.staticTexts["playback_rate_label"]
        let rateChanged = expectation(
            for: NSPredicate(format: "label != %@", rateLabel.label),
            evaluatedWith: rateLabel
        )
        speedUpButton.tap()
        speedUpButton.tap()
        wait(for: [rateChanged], timeout: 10)
        attachScreenshot(app, name: "05-player-speed")

        // 検索タブに戻りミニプレイヤーを確認
        tabBar.buttons.element(boundBy: 1).tap()
        let miniPlayer = app.descendants(matching: .any)["mini_player"].firstMatch
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10))
        attachScreenshot(app, name: "06-miniplayer")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
