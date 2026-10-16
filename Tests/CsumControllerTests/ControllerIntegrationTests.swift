import XCTest
@testable import CsumController

private let wholeSecond = Date(timeIntervalSince1970: 1700000000)

private func truncate(_ date: Date) -> Date {
    Date(timeIntervalSince1970: TimeInterval(Int64(date.timeIntervalSince1970)))
}

private func atSecondResolution(_ entry: ChecksumEntry) -> ChecksumEntry {
    ChecksumEntry(
        path: entry.path,
        outcome: entry.outcome,
        size: entry.size,
        created: entry.created.map(truncate),
        modified: entry.modified.map(truncate)
    )
}

private func atSecondResolution(_ result: ChecksumResult) -> ChecksumResult {
    ChecksumResult(
        metadata: ChecksumMetadata(
            formatVersion: result.metadata.formatVersion,
            writer: result.metadata.writer,
            toolVersion: result.metadata.toolVersion,
            algorithm: result.metadata.algorithm,
            computedAt: truncate(result.metadata.computedAt),
            root: result.metadata.root
        ),
        entries: result.entries.map(atSecondResolution)
    )
}

final class CalculateChecksumsTests: XCTestCase {
    private var tree: TempTree!

    override func setUpWithError() throws {
        tree = try TempTree()
    }

    override func tearDown() {
        tree.remove()
        tree = nil
    }

    private func controller(algorithm: ChecksumAlgorithm = .sha256) -> CsumController {
        CsumController(algorithm: algorithm, writer: CsumController.cliWriter)
    }

    func testSingleFileResult() throws {
        try tree.text("one.txt", "one", modified: wholeSecond, created: wholeSecond)

        let result = try controller().calculateChecksums(at: tree.url.appendingPathComponent("one.txt"))

        XCTAssertEqual(result.metadata.root, tree.path("one.txt"))
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].path, tree.path("one.txt"))
        XCTAssertEqual(result.entries[0].outcome, .digest(digest(of: Data("one".utf8), using: .sha256)))
        XCTAssertEqual(result.entries[0].size, 3)
        XCTAssertEqual(result.entries[0].modified, wholeSecond)
        XCTAssertEqual(result.entries[0].created, wholeSecond)
    }

    func testFolderResultUsesTheFolderAsRoot() throws {
        try tree.text("a.txt", "alpha")
        try tree.text("sub/b.txt", "beta")

        let result = try controller().calculateChecksums(at: tree.url)

        XCTAssertEqual(result.metadata.root, tree.root)
        XCTAssertEqual(result.entries.map(\.path), [tree.path("a.txt"), tree.path("sub/b.txt")])
    }

    func testMetadataRecordsTheToolAndAlgorithm() throws {
        try tree.text("a.txt", "alpha")

        for algorithm in ChecksumAlgorithm.allCases {
            let result = try controller(algorithm: algorithm).calculateChecksums(at: tree.url)

            XCTAssertEqual(result.metadata.formatVersion, CsumFormat.version)
            XCTAssertEqual(result.metadata.toolVersion, CsumFormat.toolVersion)
            XCTAssertEqual(result.metadata.writer, CsumController.cliWriter)
            XCTAssertEqual(result.metadata.algorithm, algorithm)
            XCTAssertLessThan(abs(result.metadata.computedAt.timeIntervalSinceNow), 5)
        }
    }

    func testMissingSourcesAreNotFound() {
        let missingFile = tree.url.appendingPathComponent("nope.txt")
        let missingFolder = tree.url.appendingPathComponent("nope")

        XCTAssertThrowsError(try controller().calculateChecksums(at: missingFile)) { error in
            XCTAssertEqual(error as? CsumError, .notFound(path: missingFile.path))
        }

        XCTAssertThrowsError(try controller().calculateChecksums(at: missingFolder)) { error in
            XCTAssertEqual(error as? CsumError, .notFound(path: missingFolder.path))
        }
    }

    func testProgressCountsEveryFile() throws {
        try tree.text("a.txt", "alpha")
        try tree.text("sub/b.txt", "beta")

        var updates: [(Int, Int)] = []
        _ = try controller().calculateChecksums(at: tree.url) { done, total in
            updates.append((done, total))
        }

        XCTAssertEqual(updates.map(\.1), [2, 2])
        XCTAssertEqual(updates.map(\.0).sorted(), [1, 2])
    }

    func testResultSurvivesAFileRoundTrip() throws {
        try tree.text("a.txt", "alpha", modified: wholeSecond, created: wholeSecond)
        try tree.text("sub/b.txt", "beta", modified: wholeSecond, created: wholeSecond)
        try tree.text("sub/empty.txt", "")

        let result = try controller().calculateChecksums(at: tree.url)
        let parsed = try ChecksumFileCodec.parse(ChecksumFileCodec.render(result))

        XCTAssertEqual(parsed, atSecondResolution(result))
        XCTAssertEqual(parsed.metadata.computedAt, truncate(result.metadata.computedAt))
    }

    func testFailureEntriesSurviveAFileRoundTrip() throws {
        try XCTSkipIf(getuid() == 0, "running as root, so permissions are not enforced")

        try tree.text("secret.txt", "secret")
        try tree.setPermissions(0o000, at: "secret.txt")
        defer {
            try? tree.setPermissions(0o600, at: "secret.txt")
        }

        let result = try controller().calculateChecksums(at: tree.url)
        let parsed = try ChecksumFileCodec.parse(ChecksumFileCodec.render(result))

        XCTAssertEqual(result.entries[0].outcome, .failure(.cannotOpen))
        XCTAssertEqual(parsed, atSecondResolution(result))
    }
}

final class LoadChecksumResultTests: XCTestCase {
    private var tree: TempTree!

    override func setUpWithError() throws {
        tree = try TempTree()
    }

    override func tearDown() {
        tree.remove()
        tree = nil
    }

    private func controller(algorithm: ChecksumAlgorithm = .sha256) -> CsumController {
        CsumController(algorithm: algorithm, writer: CsumController.cliWriter)
    }

    func testLoadsASavedChecksumFile() throws {
        try tree.text("a.txt", "alpha", modified: wholeSecond, created: wholeSecond)

        let computed = try controller().calculateChecksums(at: tree.url)
        let saved = tree.url.appendingPathComponent("saved.csum.csv")
        try Data(ChecksumFileCodec.render(computed).utf8).write(to: saved)

        let loaded = try controller().loadChecksumResult(at: saved)

        XCTAssertEqual(loaded, atSecondResolution(computed))
    }

    func testComputesForAFolderOnTheSpot() throws {
        try tree.text("a.txt", "alpha")

        let loaded = try controller().loadChecksumResult(at: tree.url)

        XCTAssertEqual(loaded.metadata.root, tree.root)
        XCTAssertEqual(loaded.entries.count, 1)
    }

    func testComputesForAFileOnTheSpot() throws {
        try tree.text("a.txt", "alpha")

        let loaded = try controller().loadChecksumResult(at: tree.url.appendingPathComponent("a.txt"))

        XCTAssertEqual(loaded.metadata.root, tree.path("a.txt"))
        XCTAssertEqual(loaded.entries.count, 1)
    }

    func testTheAlgorithmIsUsedForSourcesThatAreNotFiles() throws {
        try tree.text("a.txt", "alpha")

        let loaded = try controller(algorithm: .md5).loadChecksumResult(at: tree.url)

        XCTAssertEqual(loaded.metadata.algorithm, .md5)
        XCTAssertEqual(loaded.entries[0].outcome, .digest(digest(of: Data("alpha".utf8), using: .md5)))
    }

    func testMissingPathIsNotFound() {
        let missing = tree.url.appendingPathComponent("nope.csum.csv")

        XCTAssertThrowsError(try controller().loadChecksumResult(at: missing)) { error in
            XCTAssertEqual(error as? CsumError, .notFound(path: missing.path))
        }
    }
}
