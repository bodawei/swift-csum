import CsumController
import XCTest

@testable import csum

final class DiffRowsTests: XCTestCase {
    private func entry(_ path: String, checksum: String = "aa") -> ChecksumEntry {
        ChecksumEntry(
            path: path,
            outcome: .digest(checksum),
            size: 1,
            created: Date(timeIntervalSince1970: 0),
            modified: Date(timeIntervalSince1970: 0)
        )
    }

    private func comparison() -> ChecksumComparison {
        let source = ComparisonSource(
            path: "/root",
            kind: .folder,
            root: "/root",
            computedAt: Date(timeIntervalSince1970: 0)
        )

        return ChecksumComparison(
            metadata: ComparisonMetadata(
                formatVersion: CsumFormat.version,
                writer: "tests",
                toolVersion: CsumFormat.toolVersion,
                computedAt: Date(timeIntervalSince1970: 0),
                algorithm: .sha256,
                first: source,
                second: source
            ),
            unchanged: [entry("same.txt")],
            added: [entry("added.txt")],
            removed: [entry("removed.txt")],
            changed: [
                MatchedEntry(old: entry("changed.txt", checksum: "bb"), new: entry("changed.txt"))
            ],
            moved: [MatchedEntry(old: entry("from/a.txt"), new: entry("to/a.txt"))],
            renamed: [MatchedEntry(old: entry("old.txt"), new: entry("new.txt"))]
        )
    }

    func testRowCountsDoubleForPairedSections() {
        let comparison = comparison()

        XCTAssertEqual(DiffRows.rowCount(for: .unchanged, of: comparison), 1)
        XCTAssertEqual(DiffRows.rowCount(for: .added, of: comparison), 1)
        XCTAssertEqual(DiffRows.rowCount(for: .removed, of: comparison), 1)
        XCTAssertEqual(DiffRows.rowCount(for: .changed, of: comparison), 2)
        XCTAssertEqual(DiffRows.rowCount(for: .moved, of: comparison), 2)
        XCTAssertEqual(DiffRows.rowCount(for: .renamed, of: comparison), 2)
    }

    func testSingleSectionsUseTheirOwnSymbolAndTint() {
        let comparison = comparison()

        XCTAssertEqual(DiffRows.row(at: 0, in: .added, of: comparison).symbol, "+")
        XCTAssertNotNil(DiffRows.row(at: 0, in: .added, of: comparison).tint)
        XCTAssertEqual(DiffRows.row(at: 0, in: .removed, of: comparison).symbol, "−")
        XCTAssertNotNil(DiffRows.row(at: 0, in: .removed, of: comparison).tint)
        XCTAssertEqual(DiffRows.row(at: 0, in: .unchanged, of: comparison).symbol, " ")
        XCTAssertNil(DiffRows.row(at: 0, in: .unchanged, of: comparison).tint)
    }

    func testPairedSectionsRenderOldThenNew() {
        let comparison = comparison()

        for section in [ComparisonSection.changed, .moved, .renamed] {
            XCTAssertEqual(DiffRows.row(at: 0, in: section, of: comparison).symbol, "−")
            XCTAssertNotNil(DiffRows.row(at: 0, in: section, of: comparison).tint)
            XCTAssertEqual(DiffRows.row(at: 1, in: section, of: comparison).symbol, "+")
            XCTAssertNotNil(DiffRows.row(at: 1, in: section, of: comparison).tint)
        }
    }

    private func text(
        of section: ComparisonSection,
        at index: Int,
        of comparison: ChecksumComparison
    ) -> String {
        String(DiffRows.row(at: index, in: section, of: comparison).name.characters)
    }

    func testPairedSectionsUseTheMatchingSourceForEachSide() {
        let comparison = comparison()

        XCTAssertEqual(text(of: .renamed, at: 0, of: comparison), "old.txt")
        XCTAssertEqual(text(of: .renamed, at: 1, of: comparison), "new.txt")
        XCTAssertEqual(text(of: .moved, at: 0, of: comparison), "from/a.txt")
        XCTAssertEqual(text(of: .moved, at: 1, of: comparison), "to/a.txt")
    }
}
