import XCTest

@testable import CsumController

final class PerformanceTests: XCTestCase {
    private let count = 100_000

    private func entries() -> [ChecksumEntry] {
        (0..<count).map { index in
            ChecksumEntry(
                path: "folder/file-\(index).bin",
                outcome: .digest(String(format: "%064x", index)),
                size: Int64(index) * 1024,
                created: Date(timeIntervalSince1970: 0),
                modified: Date(timeIntervalSince1970: 1)
            )
        }
    }

    private func result(root: String) -> ChecksumResult {
        ChecksumResult(
            metadata: ChecksumMetadata(
                formatVersion: CsumFormat.version,
                writer: "tests",
                toolVersion: CsumFormat.toolVersion,
                algorithm: .sha256,
                computedAt: Date(timeIntervalSince1970: 2),
                root: root
            ),
            entries: entries()
        )
    }

    private func options() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        return options
    }

    func testCompareOneHundredThousandEntries() {
        let first = result(root: "/first")
        let second = result(root: "/second")
        let metadata = ComparisonMetadata(
            formatVersion: CsumFormat.version,
            writer: "tests",
            toolVersion: CsumFormat.toolVersion,
            computedAt: Date(timeIntervalSince1970: 3),
            algorithm: .sha256,
            first: ComparisonSource(
                path: "/first",
                kind: .folder,
                root: "/first",
                computedAt: first.metadata.computedAt
            ),
            second: ComparisonSource(
                path: "/second",
                kind: .folder,
                root: "/second",
                computedAt: second.metadata.computedAt
            )
        )

        measure(options: options()) {
            let comparison = ComparisonEngine.compare(
                first: first, second: second, metadata: metadata)
            XCTAssertEqual(comparison.unchanged.count, count)
        }
    }

    func testRenderAndParseOneHundredThousandRows() {
        let result = result(root: "/root")

        measure(options: options()) {
            let text = ChecksumFileCodec.render(result)
            let parsed = try? ChecksumFileCodec.parse(text)
            XCTAssertEqual(parsed?.entries.count, count)
        }
    }
}
