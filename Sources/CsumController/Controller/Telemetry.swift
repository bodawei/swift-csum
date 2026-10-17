import OpenTelemetryApi

enum Telemetry {
    private static let instrumentationName = "com.djb.csum"

    enum Keys {
        static let algorithm = "csum.algorithm"
        static let path = "csum.path"
        static let entryCount = "csum.entry_count"
        static let firstPath = "csum.first.path"
        static let secondPath = "csum.second.path"
        static let unchangedCount = "csum.unchanged.count"
        static let changedCount = "csum.changed.count"
        static let addedCount = "csum.added.count"
        static let removedCount = "csum.removed.count"
        static let movedCount = "csum.moved.count"
        static let renamedCount = "csum.renamed.count"
    }

    private static var tracer: Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: CsumFormat.toolVersion
        )
    }

    static func span<T>(
        named name: String,
        attributes: [String: AttributeValue] = [:],
        _ body: (any SpanBase) throws -> T
    ) rethrows -> T {
        try tracer
            .spanBuilder(spanName: name)
            .withActiveSpan { span in
                span.setAttributes(attributes)

                do {
                    return try body(span)
                } catch {
                    (span as? Span)?.recordException(error)
                    span.status = .error(description: "\(error)")
                    throw error
                }
            }
    }
}
