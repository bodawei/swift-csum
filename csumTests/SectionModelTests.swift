import CsumController
import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import csum

@MainActor
final class SectionModelTests: XCTestCase {
    private struct StubService: Checksumming {
        var result: Result<ChecksumResult, Error>
        var comparison: Result<ChecksumComparison, Error>?
        var table: CsvTable?

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

        func readChecksumFile(at url: URL) async throws -> ChecksumResult {
            try result.get()
        }

        func readFile(at url: URL) async throws -> CsumFileContents {
            if let table {
                return .table(table)
            }

            return .checksums(try result.get())
        }
    }

    private func makeResult() -> ChecksumResult {
        let entry = ChecksumEntry(
            path: "a.txt",
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

    func testCopyingTheChecksumWritesItToThePasteboard() async {
        let model = FileSectionModel(service: StubService(result: .success(makeResult())))

        model.fileChosen(URL(fileURLWithPath: "/tmp/a.txt"))

        await waitUntil {
            model.checksum != nil
        }

        model.copyChecksum()

        XCTAssertEqual(UIPasteboard.general.string, "abc")
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

    func testACsumFileSelectionLoadsAndExports() async {
        let model = CsumSectionModel(service: StubService(result: .success(makeResult())))

        model.fileChosen(URL(fileURLWithPath: "/tmp/docs.csum.csv"))

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
        XCTAssertEqual(model.export?.fileName, "docs.csum.csv")
        XCTAssertTrue(model.export?.text.contains("# csum-format 1.0") == true)
    }

    func testACsumFileFailureLeavesNoExport() async {
        let model = CsumSectionModel(
            service: StubService(
                result: .failure(CsumError.sourceUnreadable(path: "/tmp/docs.csum.csv")))
        )

        model.fileChosen(URL(fileURLWithPath: "/tmp/docs.csum.csv"))

        await waitUntil {
            if case .failed = model.phase {
                return true
            }

            return false
        }

        guard case .failed = model.phase else {
            return XCTFail("expected the failed phase")
        }

        XCTAssertNil(model.export)
    }

    func testLeavingTheCsumSectionCancelsAndResets() {
        let model = CsumSectionModel(service: StubService(result: .success(makeResult())))

        model.fileChosen(URL(fileURLWithPath: "/tmp/docs.csum.csv"))
        model.returned()

        guard case .idle = model.phase else {
            return XCTFail("expected the idle phase")
        }

        XCTAssertNil(model.export)
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

        XCTAssertEqual(model.export?.fileName, "Comparison.csum-compare.csv")
        XCTAssertEqual(model.export?.contentType, .csumComparison)
    }

    func testAComparisonFileSelectionLoadsATableAndKeepsItsName() async throws {
        let table = try CsvTable(
            parsing: "# Added\nChecksum,Size,Created,Modified,Path\nabc,3,0,100,./a.txt\n"
        )
        let model = CsumSectionModel(
            service: StubService(result: .success(makeResult()), table: table)
        )

        model.fileChosen(URL(fileURLWithPath: "/tmp/Comparison.csum-compare.csv"))

        XCTAssertEqual(model.path, [.result])

        await waitUntil {
            if case .loadedTable = model.phase {
                return true
            }

            return false
        }

        guard case .loadedTable(let loaded) = model.phase else {
            return XCTFail("expected the loaded table phase")
        }

        XCTAssertEqual(loaded.rows.count, 3)
        XCTAssertEqual(model.fileName, "Comparison.csum-compare.csv")
        XCTAssertEqual(model.export?.fileName, "Comparison.csum-compare.csv")
        XCTAssertEqual(model.export?.contentType, .csumComparison)
        XCTAssertTrue(model.export?.text.contains("# Added") == true)
    }

    func testCopyResultsDoesNothingWithoutAnExport() {
        let model = AppModel()
        UIPasteboard.general.string = "unchanged"

        model.copyResults()

        XCTAssertFalse(model.canCopyResults)
        XCTAssertEqual(UIPasteboard.general.string, "unchanged")
    }

    func testCopyResultsIsUnavailableWhileHelpIsOpen() async {
        let model = AppModel(demoMode: true)

        model.file.fileChosen(DemoData.fileURL)

        await waitUntil {
            model.canCopyResults
        }

        model.showHelp()
        UIPasteboard.general.string = "unchanged"
        model.copyResults()

        XCTAssertFalse(model.canCopyResults)
        XCTAssertEqual(UIPasteboard.general.string, "unchanged")
    }

    func testCopyResultsIsUnavailableWhileSaveAsIsOpen() async {
        let model = AppModel(demoMode: true)

        model.file.fileChosen(DemoData.fileURL)

        await waitUntil {
            model.canCopyResults
        }

        model.saveAs()
        UIPasteboard.general.string = "unchanged"
        model.copyResults()

        XCTAssertFalse(model.canCopyResults)
        XCTAssertEqual(UIPasteboard.general.string, "unchanged")
    }

    func testCopyResultsCopiesTheCurrentExportWithoutItsByteOrderMark() async throws {
        let model = AppModel(demoMode: true)

        model.file.fileChosen(DemoData.fileURL)

        await waitUntil {
            model.canCopyResults
        }

        model.copyResults()

        let export = try XCTUnwrap(model.currentExport)
        let copied = try XCTUnwrap(UIPasteboard.general.string)

        XCTAssertTrue(export.text.hasPrefix("\u{FEFF}"))
        XCTAssertEqual(copied, String(export.text.dropFirst()))
        XCTAssertTrue(copied.hasPrefix("# csum-format 1.0"))
        XCTAssertTrue(copied.contains("Checksum,Size,Created,Modified,Path"))
        XCTAssertTrue(copied.contains("./archive.zip"))
    }

    func testSaveAsDoesNothingWithoutAnExport() {
        let model = AppModel()

        model.saveAs()

        XCTAssertFalse(model.canSaveAs)
        XCTAssertFalse(model.isPresentingSaveAs)
    }

    #if DEBUG
        func testSaveAsPresentsTheLoadedExport() async {
            let model = AppModel(demoMode: true)

            model.file.fileChosen(DemoData.fileURL)

            await waitUntil {
                model.canSaveAs
            }

            model.saveAs()

            XCTAssertTrue(model.isPresentingSaveAs)
            XCTAssertEqual(model.currentExport?.fileName, "archive.zip.csum.csv")
        }
    #endif

    func testExportWritesTheTextToTheSuggestedFile() async throws {
        guard #available(iOS 18.2, macCatalyst 18.2, macOS 15.2, *) else {
            throw XCTSkip("export(to:contentType:) is unavailable")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let export = CsumExport(
            text: "sha256  1  a.txt\n",
            fileName: "a.txt.csum.csv",
            kind: .checksums
        ).csvFile
        let url = try await export.export(to: directory, contentType: .csumChecksums)

        XCTAssertEqual(url.lastPathComponent, "a.txt.csum.csv")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "sha256  1  a.txt\n")
    }
}
