import XCTest

@testable import CsumController

final class RelativePathTests: XCTestCase {
    func testTheRootItselfHasAnEmptyRelativePath() {
        XCTAssertEqual(CanonicalPath.relativePath(of: "/a/b", root: "/a/b"), "")
    }

    func testAPathUnderTheRootDropsThePrefix() {
        XCTAssertEqual(CanonicalPath.relativePath(of: "/a/b/c/d.txt", root: "/a/b"), "c/d.txt")
    }

    func testAPathOutsideTheRootIsReturnedUnchanged() {
        XCTAssertEqual(CanonicalPath.relativePath(of: "/other/c.txt", root: "/a/b"), "/other/c.txt")
    }

    func testARootWithATrailingSlashIsHandled() {
        XCTAssertEqual(CanonicalPath.relativePath(of: "/a/b/c.txt", root: "/a/b/"), "c.txt")
    }

    func testAResultResolvesItsEntriesAgainstItsRoot() {
        let metadata = ChecksumMetadata(
            formatVersion: CsumFormat.version,
            writer: "tests",
            toolVersion: CsumFormat.toolVersion,
            algorithm: .sha256,
            computedAt: Date(),
            root: "/a/b"
        )
        let entry = ChecksumEntry(path: "/a/b/c/d.txt", outcome: .digest("0"), size: 1)
        let result = ChecksumResult(metadata: metadata, entries: [entry])

        XCTAssertEqual(result.relativePath(of: entry), "c/d.txt")
    }
}
