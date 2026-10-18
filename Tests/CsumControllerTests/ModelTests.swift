import XCTest
@testable import CsumController

final class CsumFormatTests: XCTestCase {
    func testFormatVersionIsPinned() {
        XCTAssertEqual(CsumFormat.version, "1.0")
        XCTAssertEqual(CsumFormat.toolVersion, "1.0")
    }
}

final class ChecksumEntryTests: XCTestCase {
    func testOutcomesCompareByCaseAndPayload() {
        XCTAssertEqual(ChecksumOutcome.digest("ab"), .digest("ab"))
        XCTAssertNotEqual(ChecksumOutcome.digest("ab"), .digest("ba"))
        XCTAssertNotEqual(ChecksumOutcome.digest("ab"), .failure(.cannotOpen))
        XCTAssertNotEqual(ChecksumOutcome.failure(.cannotOpen), .failure(.readFailed))
    }

    func testEntryEqualityCoversEveryField() {
        let date = Date(timeIntervalSince1970: 1750000000)
        let base = ChecksumEntry(path: "/a", outcome: .digest("ab"), size: 1, created: date, modified: date)

        XCTAssertEqual(base, ChecksumEntry(path: "/a", outcome: .digest("ab"), size: 1, created: date, modified: date))
        XCTAssertNotEqual(base, ChecksumEntry(path: "/b", outcome: .digest("ab"), size: 1, created: date, modified: date))
        XCTAssertNotEqual(base, ChecksumEntry(path: "/a", outcome: .failure(.cannotOpen), size: 1, created: date, modified: date))
        XCTAssertNotEqual(base, ChecksumEntry(path: "/a", outcome: .digest("ab"), size: 2, created: date, modified: date))
        XCTAssertNotEqual(base, ChecksumEntry(path: "/a", outcome: .digest("ab"), size: 1, modified: date))
        XCTAssertNotEqual(base, ChecksumEntry(path: "/a", outcome: .digest("ab"), size: 1, created: date))
    }
}

final class ChecksumResultTests: XCTestCase {
    func testMetadataEqualityCoversRoot() {
        let computedAt = Date(timeIntervalSince1970: 1750000000)
        let first = ChecksumMetadata(
            formatVersion: CsumFormat.version,
            writer: "csum-cli",
            toolVersion: CsumFormat.toolVersion,
            algorithm: .sha256,
            computedAt: computedAt,
            root: "/one"
        )

        let second = ChecksumMetadata(
            formatVersion: CsumFormat.version,
            writer: "csum-cli",
            toolVersion: CsumFormat.toolVersion,
            algorithm: .sha256,
            computedAt: computedAt,
            root: "/two"
        )

        XCTAssertEqual(first, first)
        XCTAssertNotEqual(first, second)
    }
}
