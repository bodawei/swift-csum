import Foundation
import XCTest

@testable import csum

final class PostHogStartupTests: XCTestCase {
    private let bundle = Bundle(for: PostHogStartupTests.self)

    func testAConfigurationWithoutATokenIsNotStarted() {
        let startup = PostHogStartup(bundle: bundle, environment: [:])

        startup.start()

        XCTAssertFalse(startup.hasStarted)
    }

    func testStoppingBeforeStartingDoesNothing() {
        let startup = PostHogStartup(bundle: bundle, environment: [:])

        startup.stop()

        XCTAssertFalse(startup.hasStarted)
    }

    func testTheHostDefaultsToPostHogUS() {
        let configuration = PostHogConfiguration.from(
            bundle: bundle,
            environment: ["POSTHOG_PROJECT_TOKEN": "phc_test"]
        )

        XCTAssertEqual(configuration?.host, "https://us.i.posthog.com")
    }
}
