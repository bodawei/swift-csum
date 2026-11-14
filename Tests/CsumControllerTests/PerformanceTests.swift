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

    private func comparisonMetadata(_ first: ChecksumResult, _ second: ChecksumResult)
        -> ComparisonMetadata
    {
        ComparisonMetadata(
            formatVersion: CsumFormat.version,
            writer: "tests",
            toolVersion: CsumFormat.toolVersion,
            computedAt: Date(timeIntervalSince1970: 3),
            algorithm: .sha256,
            first: ComparisonSource(
                path: first.metadata.root,
                kind: .folder,
                root: first.metadata.root,
                computedAt: first.metadata.computedAt
            ),
            second: ComparisonSource(
                path: second.metadata.root,
                kind: .folder,
                root: second.metadata.root,
                computedAt: second.metadata.computedAt
            )
        )
    }

    func testCompareOneHundredThousandEntries() {
        let first = result(root: "/first")
        let second = result(root: "/second")
        let metadata = comparisonMetadata(first, second)

        measure(options: options()) {
            let comparison = ComparisonEngine.compare(
                first: first, second: second, metadata: metadata)
            XCTAssertEqual(comparison.unchanged.count, count)
        }
    }

    private static let emptyDigest =
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    private func emptyResult(root: String, folder: String) -> ChecksumResult {
        ChecksumResult(
            metadata: ChecksumMetadata(
                formatVersion: CsumFormat.version,
                writer: "tests",
                toolVersion: CsumFormat.toolVersion,
                algorithm: .sha256,
                computedAt: Date(timeIntervalSince1970: 2),
                root: root
            ),
            entries: (0..<count).map { index in
                ChecksumEntry(
                    path: "\(folder)/file-\(index).bin",
                    outcome: .digest(Self.emptyDigest),
                    size: 0
                )
            }
        )
    }

    func testCompareOneHundredThousandEmptyEntries() {
        let first = emptyResult(root: "/first", folder: "old")
        let second = emptyResult(root: "/second", folder: "new")
        let metadata = comparisonMetadata(first, second)

        measure(options: options()) {
            let comparison = ComparisonEngine.compare(
                first: first, second: second, metadata: metadata)
            XCTAssertEqual(comparison.moved.count, count)
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
