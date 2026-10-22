import XCTest
@testable import CsumController

final class ChecksumFileCodecTests: XCTestCase {
    private let computedAt = Date(timeIntervalSince1970: 1750000000)

    private func document(
        format: String = "1.0",
        writer: String = "csum-cli 1.0",
        computed: String = "2025-06-15T15:06:40Z",
        algorithm: String = "sha256",
        root: String = "/tmp/tree",
        columns: String = "Checksum,Size,Created,Modified,Path",
        comments: [String] = [],
        rows: [String] = []
    ) -> String {
        let lines = [
            "\u{FEFF}# csum-format \(format)",
            "# csum-writer \(writer)",
            "# csum-computed \(computed)",
            "# csum-algorithm \(algorithm)",
            "# csum-root \(root)"
        ] + comments + [columns] + rows

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private func metadata(root: String = "/tmp/tree", algorithm: ChecksumAlgorithm = .sha256) -> ChecksumMetadata {
        ChecksumMetadata(
            formatVersion: CsumFormat.version,
            writer: "csum-cli",
            toolVersion: CsumFormat.toolVersion,
            algorithm: algorithm,
            computedAt: computedAt,
            root: root
        )
    }

    private func assertMalformed(
        _ text: String,
        _ reason: MalformedFileReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try ChecksumFileCodec.parse(text), file: file, line: line) { error in
            XCTAssertEqual(error as? CsumError, .malformedFile(path: "", reason: reason), file: file, line: line)
        }
    }

    func testRenderProducesTheDocumentedFormat() {
        let result = ChecksumResult(
            metadata: metadata(),
            entries: [
                ChecksumEntry(
                    path: "a.txt",
                    outcome: .digest("3b1f"),
                    size: 1234,
                    created: computedAt,
                    modified: computedAt
                ),
                ChecksumEntry(path: "sub/b.bin", outcome: .failure(.cannotOpen), size: 0)
            ]
        )

        let expected = [
            "\u{FEFF}# csum-format 1.0",
            "# csum-writer csum-cli 1.0",
            "# csum-computed 2025-06-15T15:06:40Z",
            "# csum-algorithm sha256",
            "# csum-root /tmp/tree",
            "Checksum,Size,Created,Modified,Path",
            "3b1f,1234,1750000000,1750000000,./a.txt",
            "!cannotOpen,0,,,./sub/b.bin"
        ].joined(separator: "\r\n") + "\r\n"

        XCTAssertEqual(ChecksumFileCodec.render(result), expected)
    }

    func testRoundTripPreservesEveryField() throws {
        let result = ChecksumResult(
            metadata: metadata(root: "/tmp/a,b/\"tree\""),
            entries: [
                ChecksumEntry(
                    path: "a, b\"c.txt",
                    outcome: .digest("AbCdEf0123456789"),
                    size: 0,
                    created: Date(timeIntervalSince1970: 0),
                    modified: Date(timeIntervalSince1970: 1750000000)
                ),
                ChecksumEntry(path: " leading and trailing ", outcome: .failure(.readFailed), size: 7),
                ChecksumEntry(path: "üñïçø∂é/Ω.txt", outcome: .digest("ff"), size: 42, modified: nil),
                ChecksumEntry(path: "/tmp/line\nbreak.txt", outcome: .digest("00"), size: 1, created: computedAt)
            ]
        )

        XCTAssertEqual(try ChecksumFileCodec.parse(ChecksumFileCodec.render(result)), result)
    }

    func testRenderIsIdempotent() throws {
        let result = ChecksumResult(
            metadata: metadata(),
            entries: [
                ChecksumEntry(
                    path: "a.txt",
                    outcome: .digest("3b1f"),
                    size: 1234,
                    created: computedAt
                ),
                ChecksumEntry(path: "b.txt", outcome: .failure(.readFailed), size: 0)
            ]
        )

        let text = ChecksumFileCodec.render(result)

        XCTAssertEqual(ChecksumFileCodec.render(try ChecksumFileCodec.parse(text)), text)
    }

    func testEpochSecondsAreTruncatedToWholeSeconds() throws {
        let result = ChecksumResult(
            metadata: metadata(),
            entries: [
                ChecksumEntry(
                    path: "a.txt",
                    outcome: .digest("ab"),
                    size: 1,
                    created: computedAt.addingTimeInterval(0.75)
                )
            ]
        )

        let parsed = try ChecksumFileCodec.parse(ChecksumFileCodec.render(result))

        XCTAssertEqual(parsed.entries[0].created, computedAt)
    }

    func testMissingMetadataIsRejected() {
        let text = [
            "# csum-writer csum-cli 1.0",
            "Checksum,Size,Created,Modified,Path"
        ].joined(separator: "\r\n")

        assertMalformed(text, .missingMetadata)
    }

    func testUnusableMetadataValuesAreRejected() {
        assertMalformed(document(algorithm: "crc32"), .unparsableAlgorithm)
        assertMalformed(document(computed: "yesterday"), .unparsableTimestamp(section: "metadata", row: 0))
        assertMalformed(document(writer: "csum-cli"), .missingMetadata)
        assertMalformed(document(root: ""), .missingMetadata)
    }

    func testUnknownFormatVersionIsRejected() {
        XCTAssertThrowsError(try ChecksumFileCodec.parse(document(format: "2.0"))) { error in
            XCTAssertEqual(error as? CsumError, .unsupportedFormatVersion(found: "2.0", expected: CsumFormat.version))
        }
    }

    func testUnexpectedColumnsAreRejected() {
        assertMalformed(
            document(columns: "Checksum,Size,Path"),
            .unexpectedColumns(section: "checksum", expected: 5, found: 3)
        )
        assertMalformed(
            document(columns: "Path,Checksum,Size,Created,Modified"),
            .unexpectedColumns(section: "checksum", expected: 5, found: 5)
        )
    }

    func testUnterminatedQuoteIsRejected() {
        assertMalformed(document(rows: ["3b1f,1,,,\"unclosed,path"]), .unterminatedQuote)
    }

    func testUnrelatedCommentsAreIgnored() throws {
        let text = document(
            comments: ["# Checksums of files at /tmp/tree done on 2025-06-15", "#"],
            rows: ["3b1f,1234,,,./a.txt"]
        )

        let result = try ChecksumFileCodec.parse(text)

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].path, "a.txt")
        XCTAssertEqual(result.metadata.root, "/tmp/tree")
    }

    func testEmptyFileHasNoEntries() throws {
        let result = try ChecksumFileCodec.parse(document())

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.metadata, metadata())
    }

    func testParseContentsOfFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let text = document(rows: ["3b1f,1234,,,./a.txt"])
        try Data(text.utf8).write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let result = try ChecksumFileCodec.parse(contentsOf: url)

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.metadata.root, "/tmp/tree")
    }

    func testParseContentsOfUnreadableFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try ChecksumFileCodec.parse(contentsOf: url)) { error in
            XCTAssertEqual(error as? CsumError, .sourceUnreadable(path: url.path))
        }
    }

    func testMalformedFileReportsTheSourcePath() {
        let text = document(rows: ["3b1f,many,,,./a"])

        XCTAssertThrowsError(try ChecksumFileCodec.parse(text, source: "x.csum.csv")) { error in
            XCTAssertEqual(
                error as? CsumError,
                .malformedFile(path: "x.csum.csv", reason: .unparsableSize(section: "checksum", row: 0))
            )
        }
    }
}
