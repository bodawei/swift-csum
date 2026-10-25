import Foundation
import XCTest

@testable import CsumController

final class ChecksumRowTextTests: XCTestCase {
    func testALineHoldsTheRowFieldsInOrder() {
        let entry = ChecksumEntry(
            path: "sub/a.txt",
            outcome: .digest("abc"),
            size: 12,
            created: Date(timeIntervalSince1970: 100),
            modified: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(ChecksumRowText.line(for: entry), "abc,12,100,200,./sub/a.txt")
    }

    func testAPathWithACommaIsQuoted() {
        let entry = ChecksumEntry(
            path: "sub/a,b.txt",
            outcome: .digest("abc"),
            size: 12,
            created: nil,
            modified: nil
        )

        XCTAssertEqual(ChecksumRowText.line(for: entry), "abc,12,,,\"./sub/a,b.txt\"")
    }

    func testAFailedFileKeepsItsOutcomeText() {
        let entry = ChecksumEntry(
            path: "a.txt",
            outcome: .failure(.cannotOpen),
            size: 0,
            created: nil,
            modified: nil
        )

        XCTAssertEqual(ChecksumRowText.line(for: entry), "!cannotOpen,0,,,./a.txt")
    }
}
