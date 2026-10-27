import CsumController
import Foundation
import OpenTelemetryApi
import PostHog

final class Logger {
    private static let instrumentationName = "com.djb.csum"

    enum Priority: String, CaseIterable {
        case debug
        case info
        case warning
        case error
    }

    static let shared = Logger()

    private let startup: PostHogStartup

    init(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        startup = PostHogStartup(bundle: bundle, environment: environment)
    }

    var isStarted: Bool {
        startup.hasStarted
    }

    func start() {
        startup.start()
    }

    func sendEvent(name: String, properties: [String: Any]) {
        guard startup.hasStarted else {
            return
        }

        PostHogSDK.shared.capture(name, properties: properties)
    }

    func sendMessage(priority: Priority, name: String, properties: [String: Any]) {
        guard startup.hasStarted else {
            return
        }

        let postHog = PostHogSDK.shared.logger

        switch priority {
        case .debug:
            postHog?.debug(name, attributes: properties)

        case .info:
            postHog?.info(name, attributes: properties)

        case .warning:
            postHog?.warn(name, attributes: properties)

        case .error:
            postHog?.error(name, attributes: properties)
        }
    }

    func startSpan(name: String, attributes: [String: AttributeValue] = [:]) -> (any Span)? {
        guard startup.hasStarted else {
            return nil
        }

        let span =
            OpenTelemetry.instance.tracerProvider
            .get(
                instrumentationName: Self.instrumentationName,
                instrumentationVersion: CsumFormat.toolVersion
            )
            .spanBuilder(spanName: name)
            .startSpan()

        span.setAttributes(attributes)

        return span
    }

    func endSpan(_ span: (any Span)?) {
        span?.end()
    }
}
