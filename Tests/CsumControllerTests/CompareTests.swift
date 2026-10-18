import XCTest
@testable import CsumController

final class CompareTests: XCTestCase {
    private var tree: TempTree!
    private var output: TempTree!

    override func setUpWithError() throws {
        tree = try TempTree()
        output = try TempTree()
        try tree.text("a.txt", "alpha")
        try tree.text("sub/b.txt", "beta")
    }

    override func tearDown() {
        tree.remove()
        output.remove()
        tree = nil
        output = nil
    }

    private func controller(algorithm: ChecksumAlgorithm = .sha256) -> CsumController {
        CsumController(algorithm: algorithm, writer: CsumController.cliWriter)
    }

    private func saveChecksums(of url: URL, as name: String, algorithm: ChecksumAlgorithm) throws -> URL {
        let result = try controller(algorithm: algorithm).calculateChecksums(at: url)
        let saved = output.url.appendingPathComponent(name)
        try Data(ChecksumFileCodec.render(result).utf8).write(to: saved)

        return saved
    }

    func testAFolderAgainstItsOwnSavedChecksumsIsUnchanged() throws {
        let saved = try saveChecksums(of: tree.url, as: "saved.csum.csv", algorithm: .sha256)

        let comparison = try controller().compare(first: saved, second: tree.url)

        XCTAssertEqual(comparison.unchanged.map(\.path), [tree.path("a.txt"), tree.path("sub/b.txt")])
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
        XCTAssertTrue(comparison.changed.isEmpty)
    }

    func testTheSameTreeMovedSomewhereElseIsUnchanged() throws {
        let saved = try saveChecksums(of: tree.url, as: "saved.csum.csv", algorithm: .sha256)
        let moved = FileManager.default.temporaryDirectory.appendingPathComponent("csum-moved-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: tree.url, to: moved)
        defer {
            try? FileManager.default.removeItem(at: moved)
        }

        let comparison = try controller().compare(first: saved, second: moved)

        XCTAssertEqual(comparison.unchanged.count, 2)
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
        XCTAssertTrue(comparison.changed.isEmpty)
        XCTAssertEqual(comparison.metadata.first.root, tree.root)
        XCTAssertEqual(comparison.metadata.second.root, CanonicalPath.of(moved.path))
        XCTAssertNotEqual(comparison.metadata.first.root, comparison.metadata.second.root)
    }

    func testASavedFileDecidesTheAlgorithm() throws {
        let saved = try saveChecksums(of: tree.url, as: "saved.csum.csv", algorithm: .sha1)

        let comparison = try controller(algorithm: .sha256).compare(first: saved, second: tree.url)

        XCTAssertEqual(comparison.metadata.algorithm, .sha1)
        XCTAssertEqual(comparison.unchanged.count, 2)
        XCTAssertTrue(comparison.changed.isEmpty)
    }

    func testTwoSavedFilesMustAgreeOnTheAlgorithm() throws {
        let sha1 = try saveChecksums(of: tree.url, as: "sha1.csum.csv", algorithm: .sha1)
        let sha256 = try saveChecksums(of: tree.url, as: "sha256.csum.csv", algorithm: .sha256)

        XCTAssertThrowsError(try controller().compare(first: sha1, second: sha256)) { error in
            XCTAssertEqual(error as? CsumError, .algorithmMismatch(first: .sha1, second: .sha256))
        }
    }

    func testTwoLiveSourcesUseTheControllersAlgorithm() throws {
        try tree.text("a.txt", "changed")

        let comparison = try controller(algorithm: .md5).compare(first: tree.url, second: tree.url)

        XCTAssertEqual(comparison.metadata.algorithm, .md5)
        XCTAssertEqual(comparison.unchanged.count, 2)
    }

    func testTwoLiveSourcesReportDifferences() throws {
        let other = try TempTree()
        try other.text("a.txt", "alpha")
        try other.text("sub/b.txt", "BETA")
        try other.text("c.txt", "brand new")
        defer {
            other.remove()
        }

        let comparison = try controller().compare(first: tree.url, second: other.url)

        XCTAssertEqual(comparison.unchanged.map(\.path), [other.path("a.txt")])
        XCTAssertEqual(comparison.changed.count, 1)
        XCTAssertEqual(comparison.changed[0].old.path, tree.path("sub/b.txt"))
        XCTAssertEqual(comparison.changed[0].new.path, other.path("sub/b.txt"))
        XCTAssertEqual(comparison.added.map(\.path), [other.path("c.txt")])
        XCTAssertTrue(comparison.removed.isEmpty)
    }

    func testMetadataRecordsBothSources() throws {
        let saved = try saveChecksums(of: tree.url, as: "saved.csum.csv", algorithm: .sha256)

        let comparison = try controller().compare(first: saved, second: tree.url)

        XCTAssertEqual(comparison.metadata.first.path, saved.path)
        XCTAssertEqual(comparison.metadata.first.kind, .csumFile)
        XCTAssertEqual(comparison.metadata.first.root, tree.root)
        XCTAssertEqual(comparison.metadata.second.path, tree.url.path)
        XCTAssertEqual(comparison.metadata.second.kind, .folder)
        XCTAssertEqual(comparison.metadata.second.root, tree.root)
        XCTAssertEqual(comparison.metadata.formatVersion, CsumFormat.version)
        XCTAssertEqual(comparison.metadata.writer, CsumController.cliWriter)
        XCTAssertEqual(comparison.metadata.toolVersion, CsumFormat.toolVersion)
        XCTAssertLessThan(abs(comparison.metadata.computedAt.timeIntervalSinceNow), 5)
    }

    func testAFileSourceIsRecordedAsAFile() throws {
        let file = tree.url.appendingPathComponent("a.txt")
        let saved = try saveChecksums(of: file, as: "one.csum.csv", algorithm: .sha256)

        let comparison = try controller().compare(first: saved, second: file)

        XCTAssertEqual(comparison.metadata.second.kind, .file)
        XCTAssertEqual(comparison.unchanged.count, 1)
    }

    func testAMissingSideIsNotFound() throws {
        let saved = try saveChecksums(of: tree.url, as: "saved.csum.csv", algorithm: .sha256)
        let missing = tree.url.appendingPathComponent("nope.csum.csv")

        XCTAssertThrowsError(try controller().compare(first: saved, second: missing)) { error in
            XCTAssertEqual(error as? CsumError, .notFound(path: missing.path))
        }

        XCTAssertThrowsError(try controller().compare(first: missing, second: saved)) { error in
            XCTAssertEqual(error as? CsumError, .notFound(path: missing.path))
        }
    }

    func testAnUnreadableChecksumFileIsMalformed() throws {
        let broken = tree.url.appendingPathComponent("broken.csum.csv")
        try Data("nonsense\r\n".utf8).write(to: broken)

        XCTAssertThrowsError(try controller().compare(first: broken, second: tree.url)) { error in
            XCTAssertEqual(
                error as? CsumError,
                .malformedFile(path: broken.path, reason: .missingMetadata)
            )
        }
    }
}
