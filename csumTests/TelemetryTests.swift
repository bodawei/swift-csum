import Foundation
import XCTest

@testable import csum

final class TelemetryTests: XCTestCase {
    private let bundle = Bundle(for: TelemetryTests.self)

    func testNoDestinationWithoutAnEndpointOrAToken() {
        XCTAssertNil(Telemetry.destination(bundle: bundle, environment: [:]))
    }

    func testAProjectTokenSendsTracesToPostHog() {
        let destination = Telemetry.destination(
            bundle: bundle,
            environment: ["POSTHOG_PROJECT_TOKEN": "phc_test"]
        )

        XCTAssertEqual(destination?.endpoint.absoluteString, "https://us.i.posthog.com/i/v1/traces")
        XCTAssertEqual(destination?.headers.map(\.0), ["Authorization"])
        XCTAssertEqual(destination?.headers.map(\.1), ["Bearer phc_test"])
    }

    func testAPostHogHostIsUsed() {
        let destination = Telemetry.destination(
            bundle: bundle,
            environment: [
                "POSTHOG_PROJECT_TOKEN": "phc_test",
                "POSTHOG_HOST": "https://eu.i.posthog.com",
            ]
        )

        XCTAssertEqual(destination?.endpoint.absoluteString, "https://eu.i.posthog.com/i/v1/traces")
    }

    func testAHostWithAPathKeepsIt() {
        let destination = Telemetry.destination(
            bundle: bundle,
            environment: [
                "POSTHOG_PROJECT_TOKEN": "phc_test",
                "POSTHOG_HOST": "https://example.com/ingest/",
            ]
        )

        XCTAssertEqual(
            destination?.endpoint.absoluteString,
            "https://example.com/ingest/i/v1/traces"
        )
    }

    func testAnExplicitEndpointWinsAndCarriesNoAuthorization() {
        let destination = Telemetry.destination(
            bundle: bundle,
            environment: [
                "POSTHOG_PROJECT_TOKEN": "phc_test",
                "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318",
            ]
        )

        XCTAssertEqual(destination?.endpoint.absoluteString, "http://localhost:4318/v1/traces")
        XCTAssertEqual(destination?.headers.count, 0)
    }

    func testAnExplicitEndpointWithAPathIsLeftAlone() {
        let destination = Telemetry.destination(
            bundle: bundle,
            environment: ["OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318/custom/traces"]
        )

        XCTAssertEqual(destination?.endpoint.absoluteString, "http://localhost:4318/custom/traces")
    }
}
