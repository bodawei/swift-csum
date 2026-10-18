import CsumController
import XCTest

@testable import csum

@MainActor
final class SectionModelTests: XCTestCase {
    private struct StubService: Checksumming {
        var result: Result<ChecksumResult, Error>
        var comparison: Result<ChecksumComparison, Error>?

        func checksum(
            at url: URL,
            progress: @escaping @Sendable (Int, Int) -> Void
        ) async throws -> ChecksumResult {
            progress(1, 1)

            return try result.get()
        }

        func compare(first: URL, second: URL) async throws -> ChecksumComparison {
            guard let comparison else {
                throw CancellationError()
            }

            return try comparison.get()
        }
    }

    private func makeResult() -> ChecksumResult {
        let entry = ChecksumEntry(
            path: "/tmp/a.txt",
            outcome: .digest("abc"),
            size: 3,
            created: Date(timeIntervalSince1970: 0),
            modified: Date(timeIntervalSince1970: 100)
        )

        return ChecksumResult(
            metadata: ChecksumMetadata(
                formatVersion: CsumFormat.version,
                writer: "tests",
                toolVersion: CsumFormat.toolVersion,
                algorithm: .sha256,
                computedAt: Date(timeIntervalSince1970: 200),
                root: "/tmp"
            ),
            entries: [entry]
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testAFileSelectionPushesTheResultAndLoadsIt() async {
        let model = FileSectionModel(service: StubService(result: .success(makeResult())))

        model.fileChosen(URL(fileURLWithPath: "/tmp/a.txt"))

        XCTAssertEqual(model.path, [.result])

        await waitUntil {
            if case .loaded = model.phase {
                return true
            }

            return false
        }

        guard case .loaded(let result) = model.phase else {
            return XCTFail("expected the loaded phase")
        }

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertNotNil(model.export)
        XCTAssertTrue(model.export?.fileName.hasSuffix(".csum.csv") == true)
    }

    func testAFileFailureLeavesNoExport() async {
        let model = FileSectionModel(
            service: StubService(result: .failure(CsumError.notFound(path: "/tmp/a.txt")))
        )

        model.fileChosen(URL(fileURLWithPath: "/tmp/a.txt"))

        await waitUntil {
            if case .failed = model.phase {
                return true
            }

            return false
        }

        guard case .failed(let message) = model.phase else {
            return XCTFail("expected the failed phase")
        }

        XCTAssertFalse(message.isEmpty)
        XCTAssertNil(model.export)
    }

    func testLeavingTheFileSectionCancelsAndResets() {
        let model = FileSectionModel(service: StubService(result: .success(makeResult())))

        model.fileChosen(URL(fileURLWithPath: "/tmp/a.txt"))
        model.returned()

        guard case .idle = model.phase else {
            return XCTFail("expected the idle phase")
        }

        XCTAssertNil(model.export)
        XCTAssertFalse(model.showsSpinner)
    }

    func testAFolderSelectionPushesAndLoads() async {
        let model = FolderSectionModel(service: StubService(result: .success(makeResult())))

        model.folderChosen(URL(fileURLWithPath: "/tmp"))

        XCTAssertEqual(model.path, [.result])

        await waitUntil {
            if case .loaded = model.phase {
                return true
            }

            return false
        }

        guard case .loaded = model.phase else {
            return XCTFail("expected the loaded phase")
        }

        XCTAssertNil(model.progress)
        XCTAssertNotNil(model.export)
    }

    func testCompareIsOnlyAvailableWithBothSources() {
        let model = CompareSectionModel(service: StubService(result: .success(makeResult())))

        XCTAssertFalse(model.canCompare)

        model.setFirst(URL(fileURLWithPath: "/tmp/a"))
        XCTAssertFalse(model.canCompare)

        model.setSecond(URL(fileURLWithPath: "/tmp/b"))
        XCTAssertTrue(model.canCompare)
    }

    func testChangingASourceKindClearsThatSide() {
        let model = CompareSectionModel(service: StubService(result: .success(makeResult())))

        model.setFirst(URL(fileURLWithPath: "/tmp/a.csum.csv"))
        model.setSecond(URL(fileURLWithPath: "/tmp/b"))

        model.setFirstKind(.folder)

        XCTAssertNil(model.first)
        XCTAssertNotNil(model.second)
    }

    func testSwapExchangesSourcesAndKinds() {
        let model = CompareSectionModel(service: StubService(result: .success(makeResult())))
        let first = URL(fileURLWithPath: "/tmp/a")
        let second = URL(fileURLWithPath: "/tmp/b")

        model.setSecondKind(.folder)
        model.setFirst(first)
        model.setSecond(second)

        model.swap()

        XCTAssertEqual(model.first, second)
        XCTAssertEqual(model.second, first)
        XCTAssertEqual(model.firstKind, .folder)
        XCTAssertEqual(model.secondKind, .csumFile)
    }

    func testAComparisonLoadsAndExports() async {
        let result = makeResult()
        let comparison = ChecksumComparison(
            metadata: ComparisonMetadata(
                formatVersion: CsumFormat.version,
                writer: "tests",
                toolVersion: CsumFormat.toolVersion,
                computedAt: Date(timeIntervalSince1970: 300),
                algorithm: .sha256,
                first: ComparisonSource(
                    path: "/tmp/a",
                    kind: .folder,
                    root: "/tmp/a",
                    computedAt: Date(timeIntervalSince1970: 100)
                ),
                second: ComparisonSource(
                    path: "/tmp/b",
                    kind: .folder,
                    root: "/tmp/b",
                    computedAt: Date(timeIntervalSince1970: 200)
                )
            ),
            unchanged: result.entries
        )

        let model = CompareSectionModel(
            service: StubService(result: .success(result), comparison: .success(comparison))
        )

        model.setFirst(URL(fileURLWithPath: "/tmp/a"))
        model.setSecond(URL(fileURLWithPath: "/tmp/b"))
        model.compareTapped()

        XCTAssertEqual(model.path, [.result])

        await waitUntil {
            if case .loaded = model.phase {
                return true
            }

            return false
        }

        guard case .loaded = model.phase else {
            return XCTFail("expected the loaded phase")
        }

        XCTAssertNotNil(model.export)
    }
}
