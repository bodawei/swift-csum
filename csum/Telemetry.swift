import CsumController
import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import PostHog

enum Telemetry {
    private static let endpointKey = "OTEL_EXPORTER_OTLP_ENDPOINT"
    private static var isStarted = false

    static func start() {
        guard !isStarted else {
            return
        }

        isStarted = true

        guard let endpoint = tracesEndpoint() else {
            return
        }

        let exporter = OtlpHttpTraceExporter(endpoint: endpoint)
        let processor = BatchSpanProcessor(spanExporter: exporter)

        let provider = TracerProviderBuilder()
            .with(
                resource: Resource(attributes: [
                    "service.name": .string("csum"),
                    "service.version": .string(CsumFormat.toolVersion),
                ])
            )
            .add(spanProcessor: processor)
            .build()

        OpenTelemetry.registerTracerProvider(tracerProvider: provider)
    }

    private static func tracesEndpoint() -> URL? {
        let configured =
            ProcessInfo.processInfo.environment[endpointKey]
            ?? Bundle.main.object(forInfoDictionaryKey: endpointKey) as? String

        guard let configured, !configured.isEmpty, let url = URL(string: configured) else {
            return nil
        }

        if url.path.isEmpty || url.path == "/" {
            return url.appendingPathComponent("v1/traces")
        }

        return url
    }
}

enum PostHogAnalytics {
    private static let projectTokenKey = "POSTHOG_PROJECT_TOKEN"
    private static let hostKey = "POSTHOG_HOST"

    static func start() {
        guard let projectToken = configuredValue(for: projectTokenKey) else {
            missingConfiguration(projectTokenKey)
            return
        }

        guard let host = configuredValue(for: hostKey) else {
            missingConfiguration(hostKey)
            return
        }

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.errorTrackingConfig.autoCapture = true
        config.logs.serviceName = "csum"
        PostHogSDK.shared.setup(config)
    }

    private static func configuredValue(for key: String) -> String? {
        let configured =
            ProcessInfo.processInfo.environment[key]
            ?? Bundle.main.object(forInfoDictionaryKey: key) as? String

        guard let configured, !configured.isEmpty else {
            return nil
        }

        return configured
    }

    private static func missingConfiguration(_ key: String) {
        #if DEBUG
            assertionFailure(
                "\(key) variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once \(key) is configured"
            )
        #endif
    }
}

enum PostHogLogs {
    static func checksumFileCompleted(entryCount: Int) {
        PostHogSDK.shared.logger?.info(
            "checksum_file_completed",
            attributes: ["entry_count": entryCount]
        )
    }

    static func checksumFolderCompleted(entryCount: Int) {
        PostHogSDK.shared.logger?.info(
            "checksum_folder_completed",
            attributes: ["entry_count": entryCount]
        )
    }

    static func checksumComparisonCompleted(
        firstSourceType: String,
        secondSourceType: String
    ) {
        PostHogSDK.shared.logger?.info(
            "checksum_comparison_completed",
            attributes: [
                "first_source_type": firstSourceType,
                "second_source_type": secondSourceType,
            ]
        )
    }
}
