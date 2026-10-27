import Foundation
import XCTest

@testable import csum

final class LoggerTests: XCTestCase {
    private let bundle = Bundle(for: LoggerTests.self)

    func testTheLoggerIsNotStartedWithoutAProjectToken() {
        let logger = Logger(bundle: bundle, environment: [:])

        logger.start()

        XCTAssertFalse(logger.isStarted)
    }

    func testSendingWithoutAProjectTokenGoesNowhere() {
        let logger = Logger(bundle: bundle, environment: [:])

        logger.sendEvent(name: "checksum_copied", properties: ["entry_count": 3])

        for priority in Logger.Priority.allCases {
            logger.sendMessage(
                priority: priority,
                name: "checksum_file_completed",
                properties: ["entry_count": 3]
            )
        }

        XCTAssertFalse(logger.isStarted)
    }

    func testEveryPriorityHasAName() {
        XCTAssertEqual(
            Logger.Priority.allCases.map(\.rawValue),
            ["debug", "info", "warning", "error"]
        )
    }
}
