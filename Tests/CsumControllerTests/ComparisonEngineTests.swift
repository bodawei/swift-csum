import XCTest

@testable import CsumController

final class ComparisonEngineTests: XCTestCase {
    private func entry(_ path: String, _ digest: String, _ size: Int64) -> ChecksumEntry {
        ChecksumEntry(path: path, outcome: .digest(digest), size: size)
    }

    private func failure(_ path: String, _ code: ChecksumFailureCode, _ size: Int64)
        -> ChecksumEntry
    {
        ChecksumEntry(path: path, outcome: .failure(code), size: size)
    }

    private func result(root: String = "/tree", _ entries: [ChecksumEntry]) -> ChecksumResult {
        ChecksumResult(
            metadata: ChecksumMetadata(
                formatVersion: CsumFormat.version,
                writer: CsumController.cliWriter,
                toolVersion: CsumFormat.toolVersion,
                algorithm: .sha256,
                computedAt: Date(timeIntervalSince1970: 1_750_000_000),
                root: root
            ),
            entries: entries
        )
    }

    private func metadata(firstRoot: String = "/tree", secondRoot: String = "/tree")
        -> ComparisonMetadata
    {
        ComparisonMetadata(
            formatVersion: CsumFormat.version,
            writer: CsumController.cliWriter,
            toolVersion: CsumFormat.toolVersion,
            computedAt: Date(timeIntervalSince1970: 1_750_000_000),
            algorithm: .sha256,
            first: ComparisonSource(
                path: firstRoot,
                kind: .folder,
                root: firstRoot,
                computedAt: Date(timeIntervalSince1970: 1)
            ),
            second: ComparisonSource(
                path: secondRoot,
                kind: .folder,
                root: secondRoot,
                computedAt: Date(timeIntervalSince1970: 2)
            )
        )
    }

    private func compare(_ first: ChecksumResult, _ second: ChecksumResult) -> ChecksumComparison {
        ComparisonEngine.compare(
            first: first,
            second: second,
            metadata: metadata(firstRoot: first.metadata.root, secondRoot: second.metadata.root)
        )
    }

    func testIdenticalResultsAreUnchanged() {
        let entries = [entry("a.txt", "aa", 1), entry("sub/b.txt", "bb", 2)]
        let comparison = compare(result(entries), result(entries))

        XCTAssertEqual(comparison.unchanged.map(\.path), ["a.txt", "sub/b.txt"])
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
        XCTAssertTrue(comparison.changed.isEmpty)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
    }

    func testTheSameTreeAtADifferentRootIsEntirelyUnchanged() {
        let first = result(
            root: "/old/place/tree",
            [entry("a.txt", "aa", 1), entry("sub/b.txt", "bb", 2)])
        let second = result(
            root: "/new/place/tree",
            [entry("a.txt", "aa", 1), entry("sub/b.txt", "bb", 2)])

        let comparison = compare(first, second)

        XCTAssertEqual(
            comparison.unchanged.map(\.path),
            ["a.txt", "sub/b.txt"])
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
        XCTAssertTrue(comparison.changed.isEmpty)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
        XCTAssertEqual(comparison.metadata.first.root, "/old/place/tree")
        XCTAssertEqual(comparison.metadata.second.root, "/new/place/tree")
    }

    func testAddedFiles() {
        let first = result([entry("a.txt", "aa", 1)])
        let second = result([entry("a.txt", "aa", 1), entry("sub/new.txt", "cc", 3)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.added.map(\.path), ["sub/new.txt"])
        XCTAssertEqual(comparison.unchanged.map(\.path), ["a.txt"])
    }

    func testRemovedFiles() {
        let first = result([entry("a.txt", "aa", 1), entry("sub/gone.txt", "cc", 3)])
        let second = result([entry("a.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.removed.map(\.path), ["sub/gone.txt"])
    }

    func testChangedFileKeepsBothSides() {
        let first = result([entry("a.txt", "aa", 1)])
        let second = result([entry("a.txt", "zz", 1)])

        let comparison = compare(first, second)

        XCTAssertTrue(comparison.unchanged.isEmpty)
        XCTAssertEqual(comparison.changed.count, 1)
        XCTAssertEqual(comparison.changed[0].old.path, "a.txt")
        XCTAssertEqual(comparison.changed[0].old.outcome, .digest("aa"))
        XCTAssertEqual(comparison.changed[0].new.path, "a.txt")
        XCTAssertEqual(comparison.changed[0].new.outcome, .digest("zz"))
    }

    func testChangedKeepsBothSizes() {
        let first = result([entry("a.txt", "aa", 10)])
        let second = result([entry("a.txt", "aa", 20)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.changed.count, 1)
        XCTAssertEqual(comparison.changed[0].old.size, 10)
        XCTAssertEqual(comparison.changed[0].new.size, 20)
    }

    func testFileInADifferentDirectoryIsMoved() {
        let first = result([entry("one/a.txt", "aa", 1)])
        let second = result([entry("two/a.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.moved.count, 1)
        XCTAssertEqual(comparison.moved[0].old.path, "one/a.txt")
        XCTAssertEqual(comparison.moved[0].new.path, "two/a.txt")
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
    }

    func testFileUnderADifferentNameInTheSameDirectoryIsRenamed() {
        let first = result([entry("sub/old.txt", "aa", 1)])
        let second = result([entry("sub/new.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.renamed.count, 1)
        XCTAssertEqual(comparison.renamed[0].old.path, "sub/old.txt")
        XCTAssertEqual(comparison.renamed[0].new.path, "sub/new.txt")
        XCTAssertTrue(comparison.moved.isEmpty)
    }

    func testACaseOnlyRenameIsARename() {
        let first = result([entry("readme.md", "aa", 1)])
        let second = result([entry("README.md", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.renamed.count, 1)
    }

    func testAFileThatStayedPutIsUnchangedRatherThanMoved() {
        let first = result([entry("sub/a.txt", "aa", 1), entry("other/a.txt", "aa", 1)])
        let second = result([
            entry("sub/a.txt", "aa", 1), entry("other/a.txt", "aa", 1),
        ])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.unchanged.count, 2)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
    }

    func testIdenticalFilesPairDeterministically() {
        let first = result([entry("a.txt", "aa", 1), entry("b.txt", "aa", 1)])
        let second = result([entry("c.txt", "aa", 1), entry("d.txt", "aa", 1)])

        for _ in 0..<20 {
            let comparison = compare(first, second)

            XCTAssertEqual(
                comparison.renamed.map { [$0.old.path, $0.new.path] },
                [
                    ["a.txt", "c.txt"],
                    ["b.txt", "d.txt"],
                ])
            XCTAssertTrue(comparison.added.isEmpty)
            XCTAssertTrue(comparison.removed.isEmpty)
        }
    }

    func testFailuresPairByCodeAndSize() {
        let first = result([failure("a.txt", .cannotOpen, 0)])
        let second = result([failure("sub/a.txt", .cannotOpen, 0)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.moved.count, 1)
        XCTAssertEqual(comparison.moved[0].old.outcome, .failure(.cannotOpen))
    }

    func testADifferentFailureCodeIsNotAReMatch() {
        let first = result([failure("a.txt", .cannotOpen, 0)])
        let second = result([failure("a.txt", .readFailed, 0)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.changed.count, 1)
    }

    func testSectionsAreSorted() {
        let first = result([
            entry("z.txt", "zz", 1),
            entry("b.txt", "bb", 1),
            entry("a.txt", "aa", 1),
            entry("m.txt", "mm", 1),
        ])
        let second = result([
            entry("a.txt", "aa", 1),
            entry("z.txt", "yy", 1),
            entry("b.txt", "bb", 1),
            entry("q.txt", "qq", 1),
        ])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.unchanged.map(\.path), ["a.txt", "b.txt"])
        XCTAssertEqual(comparison.added.map(\.path), ["q.txt"])
        XCTAssertEqual(comparison.removed.map(\.path), ["m.txt"])
        XCTAssertEqual(comparison.changed.map(\.old.path), ["z.txt"])
    }

    func testEntriesOutsideTheRootStillCompare() {
        let first = result([entry("/elsewhere/a.txt", "aa", 1)])
        let second = result([entry("/elsewhere/a.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.unchanged.count, 1)
    }

    func testMetadataReachesTheResult() {
        let comparison = compare(result([]), result([]))

        XCTAssertEqual(comparison.metadata.first.computedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(comparison.metadata.second.computedAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(comparison.metadata.algorithm, .sha256)
    }

    func testSectionsForEmptyResults() {
        let comparison = compare(result([]), result([]))

        XCTAssertEqual(comparison.unchanged.count, 0)
        XCTAssertEqual(comparison.added.count, 0)
        XCTAssertEqual(comparison.removed.count, 0)
        XCTAssertEqual(comparison.changed.count, 0)
        XCTAssertEqual(comparison.moved.count, 0)
        XCTAssertEqual(comparison.renamed.count, 0)
    }

    func testComparisonSectionsAreOrdered() {
        XCTAssertEqual(
            ComparisonSection.allCases,
            [.added, .removed, .changed, .moved, .renamed, .unchanged]
        )
    }
}
