import Foundation
import XCTest

@testable import csum

final class TelemetryTests: XCTestCase {
    private let bundle = Bundle(for: TelemetryTests.self)

    func testNoConfigWithoutAnEndpointOrAToken() {
        XCTAssertNil(Telemetry.lookupTracesEndpointConfig(bundle: bundle, environment: [:]))
    }

    func testAProjectTokenSendsTracesToPostHog() {
        let endpointConfig = Telemetry.lookupTracesEndpointConfig(
            bundle: bundle,
            environment: ["POSTHOG_PROJECT_TOKEN": "phc_test"]
        )

        XCTAssertEqual(
            endpointConfig?.endpoint.absoluteString, "https://us.i.posthog.com/i/v1/traces")
        XCTAssertEqual(endpointConfig?.headers.map(\.0), ["Authorization"])
        XCTAssertEqual(endpointConfig?.headers.map(\.1), ["Bearer phc_test"])
    }

    func testAPostHogHostIsUsed() {
        let endpointConfig = Telemetry.lookupTracesEndpointConfig(
            bundle: bundle,
            environment: [
                "POSTHOG_PROJECT_TOKEN": "phc_test",
                "POSTHOG_HOST": "https://eu.i.posthog.com",
            ]
        )

        XCTAssertEqual(
            endpointConfig?.endpoint.absoluteString, "https://eu.i.posthog.com/i/v1/traces")
    }

    func testAHostWithAPathKeepsIt() {
        let endpointConfig = Telemetry.lookupTracesEndpointConfig(
            bundle: bundle,
            environment: [
                "POSTHOG_PROJECT_TOKEN": "phc_test",
                "POSTHOG_HOST": "https://example.com/ingest/",
            ]
        )

        XCTAssertEqual(
            endpointConfig?.endpoint.absoluteString,
            "https://example.com/ingest/i/v1/traces"
        )
    }

    func testAnExplicitEndpointWinsAndCarriesNoAuthorization() {
        let endpointConfig = Telemetry.lookupTracesEndpointConfig(
            bundle: bundle,
            environment: [
                "POSTHOG_PROJECT_TOKEN": "phc_test",
                "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318",
            ]
        )

        XCTAssertEqual(endpointConfig?.endpoint.absoluteString, "http://localhost:4318/v1/traces")
        XCTAssertEqual(endpointConfig?.headers.count, 0)
    }

    func testAnExplicitEndpointWithAPathIsLeftAlone() {
        let endpointConfig = Telemetry.lookupTracesEndpointConfig(
            bundle: bundle,
            environment: ["OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318/custom/traces"]
        )

        XCTAssertEqual(
            endpointConfig?.endpoint.absoluteString, "http://localhost:4318/custom/traces")
    }
}
