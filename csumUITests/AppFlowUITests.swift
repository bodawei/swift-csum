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
