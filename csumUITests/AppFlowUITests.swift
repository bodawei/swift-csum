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

    func testRowLongPressOffersACopy() {
        let app = launch()

        app.tabBars.buttons["Folder"].tap()
        app.buttons["Checksum Folder…"].tap()

        let row = app.staticTexts["2026-07/IMG_1042.HEIC"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.press(forDuration: 1)

        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        attach(app, name: "row-copy-menu")

        app.buttons["Copy"].tap()
    }

    func testFileCardRowOffersACopy() {
        let app = launch()

        app.buttons["Checksum File…"].tap()

        let checksum = app.staticTexts[DemoChecksums.archive]
        XCTAssertTrue(checksum.waitForExistence(timeout: 5))

        checksum.press(forDuration: 1)

        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        attach(app, name: "file-card-copy-menu")

        app.buttons["Copy"].tap()
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

    func testCsumFileFlow() {
        let app = launch()

        app.buttons["View"].firstMatch.tap()
        app.buttons["Open csum file…"].tap()

        XCTAssertTrue(app.staticTexts["/Users/demo/Pictures/2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2026-07/IMG_1042.HEIC"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].exists)
        attach(app, name: "csum-file-result")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Open csum file…"].waitForExistence(timeout: 5))
    }

    func testComparisonFileFlow() {
        let app = launch(arguments: ["-csumUITestCompareFile"])

        app.buttons["View"].firstMatch.tap()
        app.buttons["Open csum file…"].tap()

        XCTAssertTrue(app.staticTexts["# Added"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["./2026-10/scan-0003.pdf"].exists)
        XCTAssertTrue(app.buttons["Share"].exists)
        attach(app, name: "csum-compare-file-view")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Open csum file…"].waitForExistence(timeout: 5))
    }

    func testHelpFlow() {
        let app = launch()

        app.buttons["help"].tap()

        XCTAssertTrue(app.navigationBars["Help"].waitForExistence(timeout: 5))
        attach(app, name: "help-topics")

        app.buttons["help-topic-view"].tap()

        let paragraph =
            "Use View to read a checksum file back without checksumming anything again."
        XCTAssertTrue(app.staticTexts[paragraph].waitForExistence(timeout: 5))
        attach(app, name: "help-view-topic")

        app.buttons["doneHelp"].tap()
        XCTAssertTrue(app.navigationBars["Help"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Checksum File…"].waitForExistence(timeout: 5))
    }

    func testEveryPickerOffersHelp() {
        let app = launch()

        for tab in ["File", "Folder", "View", "Compare"] {
            app.buttons[tab].firstMatch.tap()
            XCTAssertTrue(app.buttons["help"].waitForExistence(timeout: 5))
        }

        attach(app, name: "picker-help")
    }

    func testHelpIsTranslated() {
        let arabic = launch(arguments: [
            "-csumUITestHelp",
            "-AppleLanguages", "(ar)",
            "-AppleLocale", "ar",
        ])

        XCTAssertTrue(arabic.buttons["help-topic-overview"].waitForExistence(timeout: 5))
        arabic.buttons["help-topic-overview"].tap()

        XCTAssertTrue(
            arabic.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "المجاميع الاختبارية")
            ).firstMatch.waitForExistence(timeout: 5)
        )
        attach(arabic, name: "help-arabic")

        arabic.terminate()

        let chinese = launch(arguments: [
            "-csumUITestHelp",
            "-AppleLanguages", "(zh-Hant)",
            "-AppleLocale", "zh_Hant_TW",
        ])

        XCTAssertTrue(chinese.buttons["help-topic-overview"].waitForExistence(timeout: 5))
        chinese.buttons["help-topic-overview"].tap()

        XCTAssertTrue(
            chinese.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "檢查碼")
            ).firstMatch.waitForExistence(timeout: 5)
        )
        attach(chinese, name: "help-traditional-chinese")
    }

    func testCompareFlow() {
        let app = launch()

        app.tabBars.buttons["Compare"].tap()
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
    static let archive = "e220a8397b1dcdaf48218226ff3cd4bf33fe8bd4f9c578631957a7604e215178"
}
