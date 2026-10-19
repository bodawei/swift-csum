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

final class CsumErrorTests: XCTestCase {
    func testEveryErrorDescribesItself() {
        let errors: [CsumError] = [
            .notFound(path: "/missing.csum.csv"),
            .sourceUnreadable(path: "/locked.csum.csv"),
            .malformedFile(path: "/broken.csum.csv", reason: .missingMetadata),
            .malformedFile(path: "/broken.csum.csv", reason: .unparsableAlgorithm),
            .malformedFile(path: "/broken.csum.csv", reason: .unparsableSourceKind(source: "tape")),
            .malformedFile(path: "/broken.csum.csv", reason: .rowOutsideSections(row: 4)),
            .malformedFile(
                path: "/broken.csum.csv",
                reason: .unexpectedColumns(section: "checksum", expected: 4, found: 3)
            ),
            .malformedFile(
                path: "/broken.csum.csv",
                reason: .wrongFieldCount(section: "checksum", row: 2, expected: 4, found: 3)
            ),
            .malformedFile(
                path: "/broken.csum.csv", reason: .unparsableSize(section: "checksum", row: 2)),
            .malformedFile(
                path: "/broken.csum.csv", reason: .unparsableTimestamp(section: "metadata", row: 0)),
            .malformedFile(
                path: "/broken.csum.csv", reason: .unparsableOutcome(section: "checksum", row: 2)),
            .malformedFile(path: "/broken.csum.csv", reason: .unterminatedQuote),
            .unsupportedFormatVersion(found: "2.0", expected: CsumFormat.version),
            .algorithmMismatch(first: .sha256, second: .sha1),
        ]

        for error in errors {
            let description = error.localizedDescription

            XCTAssertFalse(description.isEmpty)
            XCTAssertFalse(description.contains("CsumError"))
            XCTAssertFalse(description.contains("error 0"))
        }
    }

    func testAMissingFileMentionsItsPath() {
        let error = CsumError.notFound(path: "/missing.csum.csv")

        XCTAssertTrue(error.localizedDescription.contains("/missing.csum.csv"))
    }

    func testAnAlgorithmMismatchMentionsBothAlgorithms() {
        let error = CsumError.algorithmMismatch(first: .sha1, second: .md5)
        let description = error.localizedDescription

        XCTAssertTrue(description.contains("SHA-1"))
        XCTAssertTrue(description.contains("MD5"))
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
