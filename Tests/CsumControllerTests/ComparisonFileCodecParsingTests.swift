import XCTest

@testable import CsumController

final class ComparisonFileCodecParsingTests: ComparisonCodecTestCase {
    private func assertMalformed(
        _ text: String,
        _ reason: MalformedFileReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try ComparisonFileCodec.parse(text), file: file, line: line) { error in
            XCTAssertEqual(
                error as? CsumError, .malformedFile(path: "", reason: reason), file: file,
                line: line)
        }
    }

    func testRoundTripPreservesEverySection() throws {
        let result = fullComparison()

        XCTAssertEqual(try ComparisonFileCodec.parse(ComparisonFileCodec.render(result)), result)
    }

    func testRoundTripPreservesUnusualPaths() throws {
        let result = fullComparison(root: " with, spaces \"and\" quotes")

        XCTAssertEqual(try ComparisonFileCodec.parse(ComparisonFileCodec.render(result)), result)
    }

    func testRenderIsIdempotent() throws {
        let text = ComparisonFileCodec.render(fullComparison())

        XCTAssertEqual(ComparisonFileCodec.render(try ComparisonFileCodec.parse(text)), text)
    }

    func testSectionTitlesAreCaseInsensitive() throws {
        let parsed = try ComparisonFileCodec.parse(
            document(body: ["# added", "Checksum,Size,Created,Modified,Path", "bb,2,,,./a.txt"])
        )

        XCTAssertEqual(parsed.added.map(\.path), ["a.txt"])
    }

    func testUnrelatedCommentsAreIgnored() throws {
        let parsed = try ComparisonFileCodec.parse(
            document(
                body: [
                    "# Deliberately vague note about the comparison",
                    "# Unchanged",
                    "Checksum,Size,Created,Modified,Path",
                    "aa,1,,,./a.txt",
                ]
            )
        )

        XCTAssertEqual(parsed.unchanged.count, 1)
        XCTAssertEqual(parsed.metadata.algorithm, .sha256)
    }

    func testMissingMetadataIsRejected() {
        assertMalformed("Checksum,Size,Created,Modified,Path\r\n", .missingMetadata)
    }

    func testUnknownFormatVersionIsRejected() {
        XCTAssertThrowsError(try ComparisonFileCodec.parse(document(format: "2.0"))) { error in
            XCTAssertEqual(
                error as? CsumError,
                .unsupportedFormatVersion(found: "2.0", expected: CsumFormat.version))
        }
    }

    func testUnusableSourceMetadataIsRejected() {
        assertMalformed(document(kind: "nonsense"), .unparsableSourceKind(source: "first"))
        assertMalformed(
            document(computed: "yesterday"), .unparsableTimestamp(section: "metadata", row: 0))
    }

    func testUnexpectedColumnsAreRejected() {
        assertMalformed(
            document(body: ["# Added", "Checksum,Size,Path"]),
            .unexpectedColumns(section: "added", expected: 5, found: 3)
        )

        assertMalformed(
            document(body: ["# Changed", "Checksum,Size,Created,Modified,Path"]),
            .unexpectedColumns(section: "changed", expected: 10, found: 5)
        )
    }

    func testWrongPairFieldCountIsRejected() {
        assertMalformed(
            document(
                body: [
                    "# Moved",
                    "Old Checksum,Old Size,Old Created,Old Modified,Old Path,New Checksum,New Size,New Created,New Modified,New Path",
                    "ff,6,,,./a,ff,6,,",
                ]
            ),
            .wrongFieldCount(section: "moved", row: 0, expected: 10, found: 9)
        )
    }

    func testARowBeforeAnySectionIsRejected() {
        assertMalformed(
            document(body: ["Checksum,Size,Created,Modified,Path"]),
            .rowOutsideSections(row: 0)
        )
    }

    func testUnusableRowValuesAreRejected() {
        assertMalformed(
            document(body: ["# Added", "Checksum,Size,Created,Modified,Path", "zz,notanumber,,,./a"]
            ),
            .unparsableSize(section: "added", row: 0)
        )
    }

    func testUnterminatedQuoteIsRejected() {
        assertMalformed(
            document(body: ["# Added", "Checksum,Size,Created,Modified,Path", "zz,1,,,\"unclosed"]),
            .unterminatedQuote
        )
    }

    func testMalformedFileReportsTheSourcePath() {
        let text = document(body: ["# Added", "Checksum,Size,Path"])

        XCTAssertThrowsError(try ComparisonFileCodec.parse(text, source: "x.csum.csv")) { error in
            XCTAssertEqual(
                error as? CsumError,
                .malformedFile(
                    path: "x.csum.csv",
                    reason: .unexpectedColumns(section: "added", expected: 5, found: 3))
            )
        }
    }

    func testParseContentsOfFile() throws {
        let tree = try TempTree()
        defer {
            tree.remove()
        }

        let file = tree.url.appendingPathComponent("comparison.csum.csv")
        let result = fullComparison()
        try Data(ComparisonFileCodec.render(result).utf8).write(to: file)

        XCTAssertEqual(try ComparisonFileCodec.parse(contentsOf: file), result)
    }

    func testParseContentsOfUnreadableFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try ComparisonFileCodec.parse(contentsOf: url)) { error in
            XCTAssertEqual(error as? CsumError, .sourceUnreadable(path: url.path))
        }
    }
}
