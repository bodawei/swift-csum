import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import CsumController

final class TelemetryTests: XCTestCase {
    private final class Recorder: SpanProcessor, @unchecked Sendable {
        let isStartRequired = false
        let isEndRequired = true

        private let lock = NSLock()
        private var recorded: [SpanData] = []

        var spans: [SpanData] {
            lock.lock()
            defer { lock.unlock() }

            return recorded
        }

        func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

        func onEnd(span: ReadableSpan) {
            lock.lock()
            recorded.append(span.toSpanData())
            lock.unlock()
        }

        func shutdown(explicitTimeout: TimeInterval?) {}

        func forceFlush(timeout: TimeInterval?) {}
    }

    func testControllerCallsRecordSpans() throws {
        let recorder = Recorder()

        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderBuilder()
                .add(spanProcessor: recorder)
                .build()
        )

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try "hello".write(
            to: root.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )

        let controller = CsumController(algorithm: .sha256, writer: "tests")
        let checksums = try controller.calculateChecksums(at: root)

        XCTAssertEqual(checksums.entries.count, 1)

        let checksumSpans = recorder.spans.filter { $0.name == "csum.calculateChecksums" }

        XCTAssertEqual(checksumSpans.count, 1)
        XCTAssertEqual(stringAttribute(of: checksumSpans.first, key: "csum.algorithm"), "sha256")
        XCTAssertEqual(stringAttribute(of: checksumSpans.first, key: "csum.path"), root.path)
        XCTAssertEqual(intAttribute(of: checksumSpans.first, key: "csum.entry_count"), 1)

        let comparison = try controller.compare(first: root, second: root)

        XCTAssertEqual(comparison.unchanged.count, 1)

        let comparisonSpan = recorder.spans.last { $0.name == "csum.compare" }

        XCTAssertEqual(intAttribute(of: comparisonSpan, key: "csum.unchanged.count"), 1)
        XCTAssertEqual(stringAttribute(of: comparisonSpan, key: "csum.algorithm"), "sha256")

        let children = recorder.spans.filter { $0.name == "csum.calculateChecksums" }

        XCTAssertEqual(children.count, 3)
        XCTAssertTrue(children.suffix(2).allSatisfy { $0.parentSpanId == comparisonSpan?.spanId })

        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)

        XCTAssertThrowsError(try controller.calculateChecksums(at: missing))

        let failed = recorder.spans.last { $0.name == "csum.calculateChecksums" }

        guard case .error = failed?.status else {
            XCTFail("expected the span status to be an error")
            return
        }

        XCTAssertEqual(failed?.events.map(\.name), ["exception"])
    }

    private func stringAttribute(of span: SpanData?, key: String) -> String? {
        guard case .string(let value)? = span?.attributes[key] else {
            return nil
        }

        return value
    }

    private func intAttribute(of span: SpanData?, key: String) -> Int? {
        guard case .int(let value)? = span?.attributes[key] else {
            return nil
        }

        return value
    }
}
