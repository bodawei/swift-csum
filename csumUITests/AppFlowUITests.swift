import XCTest

final class AppFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFileFlow() {
        let app = launch()

        app.buttons["Checksum File…"].tap()

        XCTAssertTrue(app.staticTexts["Algorithm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["copyChecksum"].exists)
        attach(app, name: "file-result")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Checksum File…"].waitForExistence(timeout: 5))
    }

    func testFolderFlow() {
        let app = launch()

        app.buttons["Folder"].firstMatch.tap()
        app.buttons["Checksum Folder…"].tap()

        XCTAssertTrue(app.staticTexts["2026-07/IMG_1042.HEIC"].waitForExistence(timeout: 5))
        attach(app, name: "folder-result")
    }

    func testFolderResultKeepsDetailsInLandscape() {
        let app = launch()

        app.buttons["Folder"].firstMatch.tap()
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

    func testCsumFileFlow() {
        let app = launch()

        app.buttons["View"].firstMatch.tap()
        app.buttons["Open .csum.csv…"].tap()

        XCTAssertTrue(app.staticTexts["/Users/demo/Pictures/2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2026-07/IMG_1042.HEIC"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].exists)
        attach(app, name: "csum-file-result")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Open .csum.csv…"].waitForExistence(timeout: 5))
    }

    func testCompareFlow() {
        let app = launch()

        app.buttons["Compare"].firstMatch.tap()
        app.buttons["chooseFirst"].tap()
        app.buttons["chooseSecond"].tap()

        XCTAssertEqual(app.staticTexts["chooseFirstPath"].label, "/Users/demo/Pictures/2026")
        XCTAssertEqual(app.staticTexts["chooseSecondPath"].label, "/Users/demo/Pictures/2026-copy")
        attach(app, name: "compare-picker")

        XCTAssertTrue(app.buttons["compareButton"].isEnabled)
        app.buttons["compareButton"].tap()

        XCTAssertTrue(app.staticTexts["Added"].waitForExistence(timeout: 5))
        attach(app, name: "compare-result")
    }

    #if targetEnvironment(macCatalyst)
        func testSaveAsPresentsTheSavePanel() {
            let app = launch(arguments: ["-csumUITestSaveAs"])

            XCTAssertTrue(app.staticTexts["Algorithm"].waitForExistence(timeout: 5))

            let fileMenu = app.menuBars.menuBarItems["File"]
            fileMenu.click()

            for title in ["Duplicate", "Move", "Rename…", "Export As…"] {
                XCTAssertFalse(fileMenu.menuItems[title].exists)
            }

            app.menuBars.menuItems["Save As…"].click()

            XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        }
    #endif

    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-csumUITestMode"] + arguments
        app.launch()
        app.activate()

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
