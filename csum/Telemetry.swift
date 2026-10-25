import CsumController
import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk

enum Telemetry {
    private static let endpointKey = "OTEL_EXPORTER_OTLP_ENDPOINT"
    private static var isStarted = false

    static func start() {
        guard !isStarted else {
            return
        }

        isStarted = true

        guard let destination = destination() else {
            return
        }

        let exporter = OtlpHttpTraceExporter(
            endpoint: destination.endpoint,
            envVarHeaders: destination.headers.isEmpty ? nil : destination.headers
        )
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

    struct Destination: Equatable {
        let endpoint: URL
        let headers: [(String, String)]

        static func == (lhs: Destination, rhs: Destination) -> Bool {
            lhs.endpoint == rhs.endpoint && lhs.headers.map(\.0) == rhs.headers.map(\.0)
                && lhs.headers.map(\.1) == rhs.headers.map(\.1)
        }
    }

    static func destination(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Destination? {
        if let endpoint = explicitEndpoint(bundle: bundle, environment: environment) {
            return Destination(endpoint: endpoint, headers: [])
        }

        guard
            let configuration = PostHogConfiguration.from(bundle: bundle, environment: environment),
            let endpoint = configuration.tracesEndpoint
        else {
            return nil
        }

        return Destination(endpoint: endpoint, headers: configuration.tracesHeaders)
    }

    private static func explicitEndpoint(bundle: Bundle, environment: [String: String]) -> URL? {
        let configured =
            environment[endpointKey]
            ?? bundle.object(forInfoDictionaryKey: endpointKey) as? String

        guard let configured, !configured.isEmpty, let url = URL(string: configured) else {
            return nil
        }

        if url.path.isEmpty || url.path == "/" {
            return url.appendingPathComponent("v1/traces")
        }

        return url
    }
}

extension PostHogConfiguration {
    var tracesEndpoint: URL? {
        guard var components = URLComponents(string: host) else {
            return nil
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        components.path = path.isEmpty ? "/i/v1/traces" : "/\(path)/i/v1/traces"

        return components.url
    }

    var tracesHeaders: [(String, String)] {
        [("Authorization", "Bearer \(projectToken)")]
    }
}
