import XCTest
@testable import CsumController

final class CsvTests: XCTestCase {
    private func options(hasHeader: Bool = true) -> CsvOptions {
        CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: hasHeader)
    }

    func testCommentsKeepEverythingAfterTheHash() throws {
        let text = [
            "# written by csum-cli, version 1.0",
            "Checksum,Path",
            "# a note before a row, with commas",
            "3b1f,/a"
        ].joined(separator: "\r\n")

        let table = try Csv.parse(text, options: options())

        XCTAssertEqual(table.leadingComments, ["# written by csum-cli, version 1.0"])
        XCTAssertEqual(table.commentsBeforeRow[0], ["# a note before a row, with commas"])
    }

    func testCommentsSurviveAStringifyParseRoundTrip() throws {
        let leading = ["# root /tmp/a,b", "# he said \"hi\"", "# padded "]
        let beforeRow = ["# a note, with a comma"]
        var table = TableData(columns: ["Checksum", "Path"])
        table.leadingComments = leading
        table.rows = [["3b1f", "/a"], ["ab", "/b"]]
        table.commentsBeforeRow = [1: beforeRow]

        let parsed = try Csv.parse(Csv.stringify(table, options: options()), options: options())

        XCTAssertEqual(parsed.leadingComments, leading)
        XCTAssertEqual(parsed.commentsBeforeRow[1], beforeRow)
        XCTAssertEqual(parsed.rows, table.rows)
    }

    func testFieldsWithSurroundingWhitespaceSurviveARoundTrip() throws {
        let rows = [[" padded ", "trailing "], [" ", "plain"]]
        let table = TableData(rows: rows)

        let text = Csv.stringify(table, options: options(hasHeader: false))
        let parsed = try Csv.parse(text, options: options(hasHeader: false))

        XCTAssertEqual(parsed.rows, rows)
    }

    func testQuotedFieldsSurviveARoundTrip() throws {
        let rows = [["a,b", "he said \"hi\"", "line\nbreak"], ["plain", "", "x"]]
        let table = TableData(rows: rows)

        let text = Csv.stringify(table, options: options(hasHeader: false))
        let parsed = try Csv.parse(text, options: options(hasHeader: false))

        XCTAssertEqual(parsed.rows, rows)
    }

    func testHashOnlyStartsACommentInTheFirstField() throws {
        let parsed = try Csv.parse("3b1f,#tag", options: options(hasHeader: false))

        XCTAssertEqual(parsed.rows, [["3b1f", "#tag"]])
    }
}
