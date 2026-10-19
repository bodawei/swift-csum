import XCTest

final class AppFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFileFlow() {
        let app = launch()

        app.buttons["Checksum File…"].tap()

        XCTAssertTrue(app.staticTexts["Algorithm"].waitForExistence(timeout: 5))
        attach(app, name: "file-result")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Checksum File…"].waitForExistence(timeout: 5))
    }

    func testFolderFlow() {
        let app = launch()

        app.tabBars.buttons["Folder"].tap()
        app.buttons["Checksum Folder…"].tap()

        XCTAssertTrue(app.staticTexts["2026-07/IMG_1042.HEIC"].waitForExistence(timeout: 5))
        attach(app, name: "folder-result")
    }

    func testFolderResultKeepsDetailsInLandscape() {
        let app = launch()

        app.tabBars.buttons["Folder"].tap()
        app.buttons["Checksum Folder…"].tap()

        XCTAssertTrue(app.staticTexts["2026-07/IMG_1042.HEIC"].waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        defer {
            XCUIDevice.shared.orientation = .portrait
        }

        let window = app.windows.firstMatch
        XCTAssertGreaterThan(window.frame.width, window.frame.height)
        XCTAssertTrue(app.staticTexts[DemoChecksums.image1042].waitForExistence(timeout: 5))
        attach(app, name: "folder-result-landscape")
    }

    func testCompareFlow() {
        let app = launch()

        app.tabBars.buttons["Compare"].tap()
        app.buttons["chooseFirst"].tap()
        app.buttons["chooseSecond"].tap()

        XCTAssertTrue(app.buttons["compareButton"].isEnabled)
        app.buttons["compareButton"].tap()

        XCTAssertTrue(app.staticTexts["Added"].waitForExistence(timeout: 5))
        attach(app, name: "compare-result")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-csumUITestMode"]
        app.launch()

        return app
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private enum DemoChecksums {
    static let image1042 = "6e789e6aa1b965f4cd73fe3de975ac2663a267815dcaa86a67185c5a5b0de1ab"
}
