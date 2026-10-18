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
