import XCTest
@testable import CsumController

final class ComparisonEngineTests: XCTestCase {
    private func entry(_ path: String, _ digest: String, _ size: Int64) -> ChecksumEntry {
        ChecksumEntry(path: path, outcome: .digest(digest), size: size)
    }

    private func failure(_ path: String, _ code: ChecksumFailureCode, _ size: Int64) -> ChecksumEntry {
        ChecksumEntry(path: path, outcome: .failure(code), size: size)
    }

    private func result(root: String = "/tree", _ entries: [ChecksumEntry]) -> ChecksumResult {
        ChecksumResult(
            metadata: ChecksumMetadata(
                formatVersion: CsumFormat.version,
                writer: CsumController.cliWriter,
                toolVersion: CsumFormat.toolVersion,
                algorithm: .sha256,
                computedAt: Date(timeIntervalSince1970: 1750000000),
                root: root
            ),
            entries: entries
        )
    }

    private func metadata(firstRoot: String = "/tree", secondRoot: String = "/tree") -> ComparisonMetadata {
        ComparisonMetadata(
            formatVersion: CsumFormat.version,
            writer: CsumController.cliWriter,
            toolVersion: CsumFormat.toolVersion,
            computedAt: Date(timeIntervalSince1970: 1750000000),
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
        let entries = [entry("/tree/a.txt", "aa", 1), entry("/tree/sub/b.txt", "bb", 2)]
        let comparison = compare(result(entries), result(entries))

        XCTAssertEqual(comparison.unchanged.map(\.path), ["/tree/a.txt", "/tree/sub/b.txt"])
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
        XCTAssertTrue(comparison.changed.isEmpty)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
    }

    func testTheSameTreeAtADifferentRootIsEntirelyUnchanged() {
        let first = result(root: "/old/place/tree", [entry("/old/place/tree/a.txt", "aa", 1), entry("/old/place/tree/sub/b.txt", "bb", 2)])
        let second = result(root: "/new/place/tree", [entry("/new/place/tree/a.txt", "aa", 1), entry("/new/place/tree/sub/b.txt", "bb", 2)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.unchanged.map(\.path), ["/new/place/tree/a.txt", "/new/place/tree/sub/b.txt"])
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
        XCTAssertTrue(comparison.changed.isEmpty)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
        XCTAssertEqual(comparison.metadata.first.root, "/old/place/tree")
        XCTAssertEqual(comparison.metadata.second.root, "/new/place/tree")
    }

    func testAddedFiles() {
        let first = result([entry("/tree/a.txt", "aa", 1)])
        let second = result([entry("/tree/a.txt", "aa", 1), entry("/tree/sub/new.txt", "cc", 3)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.added.map(\.path), ["/tree/sub/new.txt"])
        XCTAssertEqual(comparison.unchanged.map(\.path), ["/tree/a.txt"])
    }

    func testRemovedFiles() {
        let first = result([entry("/tree/a.txt", "aa", 1), entry("/tree/sub/gone.txt", "cc", 3)])
        let second = result([entry("/tree/a.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.removed.map(\.path), ["/tree/sub/gone.txt"])
    }

    func testChangedFileKeepsBothSides() {
        let first = result([entry("/tree/a.txt", "aa", 1)])
        let second = result([entry("/tree/a.txt", "zz", 1)])

        let comparison = compare(first, second)

        XCTAssertTrue(comparison.unchanged.isEmpty)
        XCTAssertEqual(comparison.changed.count, 1)
        XCTAssertEqual(comparison.changed[0].old.path, "/tree/a.txt")
        XCTAssertEqual(comparison.changed[0].old.outcome, .digest("aa"))
        XCTAssertEqual(comparison.changed[0].new.path, "/tree/a.txt")
        XCTAssertEqual(comparison.changed[0].new.outcome, .digest("zz"))
    }

    func testChangedKeepsBothSizes() {
        let first = result([entry("/tree/a.txt", "aa", 10)])
        let second = result([entry("/tree/a.txt", "aa", 20)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.changed.count, 1)
        XCTAssertEqual(comparison.changed[0].old.size, 10)
        XCTAssertEqual(comparison.changed[0].new.size, 20)
    }

    func testFileInADifferentDirectoryIsMoved() {
        let first = result([entry("/tree/one/a.txt", "aa", 1)])
        let second = result([entry("/tree/two/a.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.moved.count, 1)
        XCTAssertEqual(comparison.moved[0].old.path, "/tree/one/a.txt")
        XCTAssertEqual(comparison.moved[0].new.path, "/tree/two/a.txt")
        XCTAssertTrue(comparison.added.isEmpty)
        XCTAssertTrue(comparison.removed.isEmpty)
    }

    func testFileUnderADifferentNameInTheSameDirectoryIsRenamed() {
        let first = result([entry("/tree/sub/old.txt", "aa", 1)])
        let second = result([entry("/tree/sub/new.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.renamed.count, 1)
        XCTAssertEqual(comparison.renamed[0].old.path, "/tree/sub/old.txt")
        XCTAssertEqual(comparison.renamed[0].new.path, "/tree/sub/new.txt")
        XCTAssertTrue(comparison.moved.isEmpty)
    }

    func testACaseOnlyRenameIsARename() {
        let first = result([entry("/tree/readme.md", "aa", 1)])
        let second = result([entry("/tree/README.md", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.renamed.count, 1)
    }

    func testAFileThatStayedPutIsUnchangedRatherThanMoved() {
        let first = result([entry("/tree/sub/a.txt", "aa", 1), entry("/tree/other/a.txt", "aa", 1)])
        let second = result([entry("/tree/sub/a.txt", "aa", 1), entry("/tree/other/a.txt", "aa", 1)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.unchanged.count, 2)
        XCTAssertTrue(comparison.moved.isEmpty)
        XCTAssertTrue(comparison.renamed.isEmpty)
    }

    func testIdenticalFilesPairDeterministically() {
        let first = result([entry("/tree/a.txt", "aa", 1), entry("/tree/b.txt", "aa", 1)])
        let second = result([entry("/tree/c.txt", "aa", 1), entry("/tree/d.txt", "aa", 1)])

        for _ in 0 ..< 20 {
            let comparison = compare(first, second)

            XCTAssertEqual(comparison.renamed.map { [$0.old.path, $0.new.path] }, [
                ["/tree/a.txt", "/tree/c.txt"],
                ["/tree/b.txt", "/tree/d.txt"]
            ])
            XCTAssertTrue(comparison.added.isEmpty)
            XCTAssertTrue(comparison.removed.isEmpty)
        }
    }

    func testFailuresPairByCodeAndSize() {
        let first = result([failure("/tree/a.txt", .cannotOpen, 0)])
        let second = result([failure("/tree/sub/a.txt", .cannotOpen, 0)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.moved.count, 1)
        XCTAssertEqual(comparison.moved[0].old.outcome, .failure(.cannotOpen))
    }

    func testADifferentFailureCodeIsNotAReMatch() {
        let first = result([failure("/tree/a.txt", .cannotOpen, 0)])
        let second = result([failure("/tree/a.txt", .readFailed, 0)])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.changed.count, 1)
    }

    func testSectionsAreSorted() {
        let first = result([
            entry("/tree/z.txt", "zz", 1),
            entry("/tree/b.txt", "bb", 1),
            entry("/tree/a.txt", "aa", 1),
            entry("/tree/m.txt", "mm", 1)
        ])
        let second = result([
            entry("/tree/a.txt", "aa", 1),
            entry("/tree/z.txt", "yy", 1),
            entry("/tree/b.txt", "bb", 1),
            entry("/tree/q.txt", "qq", 1)
        ])

        let comparison = compare(first, second)

        XCTAssertEqual(comparison.unchanged.map(\.path), ["/tree/a.txt", "/tree/b.txt"])
        XCTAssertEqual(comparison.added.map(\.path), ["/tree/q.txt"])
        XCTAssertEqual(comparison.removed.map(\.path), ["/tree/m.txt"])
        XCTAssertEqual(comparison.changed.map(\.old.path), ["/tree/z.txt"])
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
