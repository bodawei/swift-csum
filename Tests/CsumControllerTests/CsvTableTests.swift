import Foundation
import XCTest

@testable import CsumController

final class CsvTableTests: XCTestCase {
    private let comparison = """
        # csum-format 1.0
        # csum-writer csum 1.0
        # Added
        Checksum,Size,Created,Modified,Path
        abc,3,0,100,./a.txt
        # Removed
        Checksum,Size,Created,Modified,Path
        def,4,0,200,./b.txt

        """

    func testCommentsBecomeRowsWithTheTextInTheFirstColumn() throws {
        let table = try CsvTable(parsing: comparison)

        XCTAssertEqual(table.rows[0].fields, ["# csum-format 1.0"])
        XCTAssertTrue(table.rows[0].isComment)
        XCTAssertEqual(table.rows[2].fields, ["# Added"])
        XCTAssertEqual(table.rows[3].fields.first, "Checksum")
        XCTAssertFalse(table.rows[3].isComment)
        XCTAssertEqual(table.rows[4].fields, ["abc", "3", "0", "100", "./a.txt"])
    }

    func testEveryRowKeepsItsPosition() throws {
        let table = try CsvTable(parsing: comparison)

        XCTAssertEqual(table.rows.map(\.id), Array(0..<table.rows.count))
        XCTAssertEqual(table.rows.count, 8)
    }

    func testTheWidestRowSetsTheColumnCount() throws {
        let table = try CsvTable(
            parsing: "# Changed\nOld Checksum,Old Size\nabc,3\n# Added\nChecksum,Size\n"
        )

        XCTAssertEqual(table.columnCount, 2)
    }

    func testTheOriginalTextIsKeptForExporting() throws {
        let table = try CsvTable(parsing: comparison)

        XCTAssertEqual(table.text, comparison)
    }

    func testAnUnterminatedQuoteIsAMalformedFile() {
        XCTAssertThrowsError(try CsvTable(parsing: "\"abc\n", source: "/tmp/a.csv")) { error in
            XCTAssertEqual(
                error as? CsumError,
                .malformedFile(path: "/tmp/a.csv", reason: .unterminatedQuote)
            )
        }
    }

    func testReadingAComparisonFileGivesATable() throws {
        let tree = try TempTree()

        defer {
            tree.remove()
        }

        let url = try tree.text("Comparison.csum-compare.csv", comparison)
        let controller = CsumController(algorithm: .sha256, writer: CsumController.appWriter)

        guard case .table(let table) = try controller.readFile(at: url) else {
            return XCTFail("expected a table")
        }

        XCTAssertEqual(table.rows.count, 8)
    }

    func testReadingAChecksumFileGivesChecksums() throws {
        let tree = try TempTree()

        defer {
            tree.remove()
        }

        let file = try tree.text("a.txt", "abc")
        let controller = CsumController(algorithm: .sha256, writer: CsumController.appWriter)
        let result = try controller.calculateChecksums(at: file)
        let url = try tree.text("a.csum.csv", ChecksumFileCodec.render(result))

        guard case .checksums(let read) = try controller.readFile(at: url) else {
            return XCTFail("expected checksums")
        }

        XCTAssertEqual(read.entries.count, 1)
    }

    func testAComparisonFileIsNotAChecksumFile() throws {
        let tree = try TempTree()

        defer {
            tree.remove()
        }

        let url = try tree.text("Comparison.csum-compare.csv", comparison)
        let controller = CsumController(algorithm: .sha256, writer: CsumController.appWriter)

        XCTAssertThrowsError(try controller.readChecksumFile(at: url))
    }
}
