import XCTest
@testable import CsumController

final class EntryRowCodecTests: XCTestCase {
    private func assertReason(
        _ expected: MalformedFileReason,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> ChecksumEntry
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual((error as? MalformedFile)?.reason, expected, file: file, line: line)
        }
    }

    func testRowAndEntryRoundTrip() throws {
        let entries = [
            ChecksumEntry(path: "/a", outcome: .digest("3b1f"), size: 0),
            ChecksumEntry(
                path: "/b, \"quoted\"",
                outcome: .failure(.cannotOpen),
                size: 1234,
                created: Date(timeIntervalSince1970: 0),
                modified: Date(timeIntervalSince1970: 1750000000)
            ),
            ChecksumEntry(path: "/c", outcome: .failure(.readFailed), size: 9, created: Date(timeIntervalSince1970: 5))
        ]

        for entry in entries {
            let row = EntryRowCodec.row(for: entry)
            let decoded = try EntryRowCodec.entry(from: row, section: "s", rowIndex: 0)

            XCTAssertEqual(decoded, entry)
        }
    }

    func testOutcomeTokensAreStable() {
        XCTAssertEqual(EntryRowCodec.token(for: .cannotOpen), "cannotOpen")
        XCTAssertEqual(EntryRowCodec.token(for: .readFailed), "readFailed")
        XCTAssertEqual(EntryRowCodec.code(forToken: "cannotOpen"), .cannotOpen)
        XCTAssertEqual(EntryRowCodec.code(forToken: "readFailed"), .readFailed)
        XCTAssertNil(EntryRowCodec.code(forToken: "somethingElse"))
        XCTAssertNil(EntryRowCodec.code(forToken: ""))
    }

    func testOutcomeTextPutsFailuresBehindABang() {
        XCTAssertEqual(EntryRowCodec.outcomeText(for: .digest("3b1f")), "3b1f")
        XCTAssertEqual(EntryRowCodec.outcomeText(for: .failure(.cannotOpen)), "!cannotOpen")
        XCTAssertEqual(EntryRowCodec.outcomeText(for: .failure(.readFailed)), "!readFailed")
    }

    func testHexDigestsAreAcceptedInEitherCase() throws {
        let upper = try EntryRowCodec.entry(from: ["3B1FAF", "1", "", "", "/a"], section: "s", rowIndex: 0)
        let lower = try EntryRowCodec.entry(from: ["3b1faf", "1", "", "", "/a"], section: "s", rowIndex: 0)

        XCTAssertEqual(upper.outcome, .digest("3B1FAF"))
        XCTAssertEqual(lower.outcome, .digest("3b1faf"))
    }

    func testSubSecondTimestampsAreTruncated() throws {
        let entry = ChecksumEntry(
            path: "/a",
            outcome: .digest("3b1f"),
            size: 1,
            modified: Date(timeIntervalSince1970: 1750000000.75)
        )

        let decoded = try EntryRowCodec.entry(from: EntryRowCodec.row(for: entry), section: "s", rowIndex: 0)

        XCTAssertEqual(decoded.modified, Date(timeIntervalSince1970: 1750000000))
    }

    func testNegativeEpochSecondsAreAccepted() throws {
        let decoded = try EntryRowCodec.entry(from: ["3b1f", "1", "-1", "-1", "/a"], section: "s", rowIndex: 0)

        XCTAssertEqual(decoded.created, Date(timeIntervalSince1970: -1))
        XCTAssertEqual(decoded.modified, Date(timeIntervalSince1970: -1))
    }

    func testUnusableRowsAreRejected() {
        assertReason(.wrongFieldCount(section: "s", row: 2, expected: 5, found: 3)) {
            try EntryRowCodec.entry(from: ["3b1f", "1", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableSize(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["3b1f", "many", "", "", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableTimestamp(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["3b1f", "1", "soon", "", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableTimestamp(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["3b1f", "1", "", "later", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableOutcome(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["", "1", "", "", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableOutcome(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["nothex", "1", "", "", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableOutcome(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["!", "1", "", "", "/a"], section: "s", rowIndex: 2)
        }

        assertReason(.unparsableOutcome(section: "s", row: 2)) {
            try EntryRowCodec.entry(from: ["!cannotRead", "1", "", "", "/a"], section: "s", rowIndex: 2)
        }
    }

    func testEmptyFieldsAreReadAsNilTimestamps() throws {
        let decoded = try EntryRowCodec.entry(from: ["3b1f", "1", "", "", "/a"], section: "s", rowIndex: 0)

        XCTAssertNil(decoded.created)
        XCTAssertNil(decoded.modified)
    }

    func testMetadataCommentsLineIsPlainText() {
        XCTAssertEqual(MetadataComments.line(key: "csum-root", value: "/tmp/plain"), "# csum-root /tmp/plain")
        XCTAssertEqual(MetadataComments.line(key: "csum-root", value: "/tmp/a,b"), "# csum-root /tmp/a,b")
    }

    func testMetadataCommentKeysAreParsed() {
        XCTAssertEqual(MetadataComments.keyValue(from: "# csum-format 1.0")?.key, "csum-format")
        XCTAssertEqual(MetadataComments.keyValue(from: "# csum-format 1.0")?.value, "1.0")
        XCTAssertEqual(MetadataComments.keyValue(from: "# csum-root  /a")?.value, " /a")
        XCTAssertEqual(MetadataComments.keyValue(from: "# csum-writer csum-cli 1.0")?.value, "csum-cli 1.0")
        XCTAssertEqual(MetadataComments.keyValue(from: "# csum-root")?.value, "")
        XCTAssertNil(MetadataComments.keyValue(from: "# a note"))
        XCTAssertNil(MetadataComments.keyValue(from: "not a comment"))
    }

    func testMetadataValuesCollectCsumKeysOnly() {
        let values = MetadataComments.values(from: [
            "# written by csum-cli",
            "# csum-format 1.0",
            "# csum-root /tmp/a",
            "# csum-format 0.9"
        ])

        XCTAssertEqual(values, ["csum-format": "0.9", "csum-root": "/tmp/a"])
    }
}
