import XCTest
@testable import CsumController

final class EntryCollectorTests: XCTestCase {
    private var tree: TempTree!

    override func setUpWithError() throws {
        tree = try TempTree()
    }

    override func tearDown() {
        tree.remove()
        tree = nil
    }

    func testCollectsEveryFileUnderAFolderSortedByPath() throws {
        try tree.text("b.txt", "b")
        try tree.text("a.txt", "a")
        try tree.text("one/two/three/deep.txt", "deep")
        try tree.text("one/mid.txt", "mid")

        let entries = try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil)
        let expected = [
            tree.path("a.txt"),
            tree.path("b.txt"),
            tree.path("one/mid.txt"),
            tree.path("one/two/three/deep.txt")
        ]

        XCTAssertEqual(entries.map(\.path), expected)
    }

    func testIncludesHiddenFiles() throws {
        try tree.text(".hidden-file", "hidden")
        try tree.text(".hidden/nested.txt", "nested")

        let entries = try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil)

        XCTAssertEqual(
            entries.map(\.path).sorted(),
            [tree.path(".hidden-file"), tree.path(".hidden/nested.txt")].sorted()
        )
    }

    func testSkipsSymlinksWithoutFollowingThem() throws {
        let file = try tree.text("real.txt", "real")
        try tree.folder("sub")
        try tree.text("sub/other.txt", "other")
        try tree.symlink("link.txt", to: file)
        try tree.symlink("link-to-sub", to: tree.url.appendingPathComponent("sub"))
        try tree.symlink("link-to-root", to: tree.url)

        let entries = try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil)

        XCTAssertEqual(entries.map(\.path), [tree.path("real.txt"), tree.path("sub/other.txt")])
    }

    func testEmptyFolderYieldsNoEntries() throws {
        try tree.folder("empty")

        XCTAssertEqual(try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil).count, 0)
    }

    func testUnreadableFileBecomesACannotOpenFailure() throws {
        try XCTSkipIf(getuid() == 0, "running as root, so permissions are not enforced")

        try tree.text("readable.txt", "readable")
        try tree.text("secret.txt", "secret")
        try tree.setPermissions(0o000, at: "secret.txt")
        defer {
            try? tree.setPermissions(0o600, at: "secret.txt")
        }

        let entries = try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil)

        XCTAssertEqual(entries.count, 2)

        let secret = try XCTUnwrap(entries.first { $0.path == tree.path("secret.txt") })
        let readable = try XCTUnwrap(entries.first { $0.path == tree.path("readable.txt") })

        XCTAssertEqual(secret.outcome, .failure(.cannotOpen))
        XCTAssertEqual(readable.outcome, .digest(digest(of: Data("readable".utf8), using: .sha256)))
    }

    func testDigestsMatchTheAlgorithm() throws {
        let contents = Data((0 ..< 3_000_000).map { UInt8($0 % 251) })
        try tree.file("big.bin", contents: contents)

        for algorithm in ChecksumAlgorithm.allCases {
            let entries = try EntryCollector.entries(in: tree.url, algorithm: algorithm, progress: nil)

            XCTAssertEqual(entries[0].outcome, .digest(digest(of: contents, using: algorithm)))
        }
    }

    func testUnusualFileNamesSurviveTheWalk() throws {
        let names = ["a b.txt", "a,b.txt", "a\"b.txt", "üñïçø∂é.txt", " padded .txt"]

        for name in names {
            try tree.text(name, name)
        }

        let entries = try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil)

        XCTAssertEqual(entries.map(\.path).sorted(), names.map(tree.path).sorted())
    }

    func testRecordsSizeAndDates() throws {
        let created = Date(timeIntervalSince1970: 1600000000)
        let modified = Date(timeIntervalSince1970: 1700000000)
        try tree.text("dated.txt", "1234567", modified: modified, created: created)

        let entries = try EntryCollector.entries(in: tree.url, algorithm: .sha256, progress: nil)

        XCTAssertEqual(entries[0].size, 7)
        XCTAssertEqual(entries[0].modified, modified)
        XCTAssertEqual(entries[0].created, created)
    }

    func testProgressCountsUpToTheTotal() throws {
        for index in 0 ..< 5 {
            try tree.text("file\(index).txt", "\(index)")
        }

        var updates: [(Int, Int)] = []
        _ = try EntryCollector.entries(in: tree.url, algorithm: .sha256) { done, total in
            updates.append((done, total))
        }

        XCTAssertEqual(updates.map(\.1), [5, 5, 5, 5, 5])
        XCTAssertEqual(updates.map(\.0), [1, 2, 3, 4, 5])
    }

    func testSingleFileEntry() throws {
        let file = try tree.text("one.txt", "one")
        let entry = EntryCollector.entry(for: file, algorithm: .sha256)

        XCTAssertEqual(entry.path, tree.path("one.txt"))
        XCTAssertEqual(entry.outcome, .digest(digest(of: Data("one".utf8), using: .sha256)))
        XCTAssertEqual(entry.size, 3)
    }

    func testSingleMissingFileIsAReadFailure() {
        let missing = tree.url.appendingPathComponent("nope.txt")
        let entry = EntryCollector.entry(for: missing, algorithm: .sha256)

        XCTAssertEqual(entry.outcome, .failure(.cannotOpen))
    }

    func testCanonicalPathResolvesLinks() throws {
        let folder = try tree.folder("real-folder")
        try tree.symlink("folder-link", to: folder)

        XCTAssertEqual(
            CanonicalPath.of(tree.url.appendingPathComponent("folder-link").path),
            CanonicalPath.of(folder.path)
        )
    }

    func testCanonicalPathFallsBackForMissingPaths() {
        let missing = "/definitely/not/here/\(UUID().uuidString)"

        XCTAssertEqual(CanonicalPath.of(missing), missing)
    }
}
