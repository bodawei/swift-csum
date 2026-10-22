import XCTest

@testable import CsumController

final class ComparisonFileCodecRenderingTests: ComparisonCodecTestCase {
    func testRenderProducesTheDocumentedFormat() {
        let result = comparison(
            added: [entry("added.txt", "bb", 2)],
            changed: [
                MatchedEntry(
                    old: entry("changed.txt", "dd", 4), new: entry("changed.txt", "ee", 5)
                )
            ]
        )

        let expected =
            [
                "\u{FEFF}# csum-format 1.0",
                "# csum-writer csum-cli 1.0",
                "# csum-computed 2025-06-15T15:06:40Z",
                "# csum-algorithm sha256",
                "# csum-first-path /old.csum.csv",
                "# csum-first-kind csumFile",
                "# csum-first-root /old",
                "# csum-first-computed 2025-06-15T15:06:40Z",
                "# csum-second-path /new",
                "# csum-second-kind folder",
                "# csum-second-root /new",
                "# csum-second-computed 2025-06-14T11:20:00Z",
                "# Added",
                "Checksum,Size,Created,Modified,Path",
                "bb,2,,,./added.txt",
                "# Changed",
                "Old Checksum,Old Size,Old Created,Old Modified,Old Path,New Checksum,New Size,New Created,New Modified,New Path",
                "dd,4,,,./changed.txt,ee,5,,,./changed.txt",
            ].joined(separator: "\r\n") + "\r\n"

        XCTAssertEqual(
            ComparisonFileCodec.render(result, sections: [.added, .changed]),
            expected
        )
    }

    func testAllSectionsAreWrittenByDefault() {
        let text = ComparisonFileCodec.render(fullComparison())

        for title in ["# Added", "# Removed", "# Changed", "# Moved", "# Renamed", "# Unchanged"] {
            XCTAssertTrue(text.contains(title), "missing \(title)")
        }
    }

    func testOnlyTheChosenSectionsAreWritten() {
        let text = ComparisonFileCodec.render(fullComparison(), sections: [.changed, .renamed])

        XCTAssertTrue(text.contains("# Changed"))
        XCTAssertTrue(text.contains("# Renamed"))
        XCTAssertFalse(text.contains("# Added"))
        XCTAssertFalse(text.contains("# Removed"))
        XCTAssertFalse(text.contains("# Moved"))
        XCTAssertFalse(text.contains("# Unchanged"))
    }

    func testSectionsAreWrittenInCanonicalOrder() throws {
        let text = ComparisonFileCodec.render(fullComparison())
        let order = ["# Added", "# Removed", "# Changed", "# Moved", "# Renamed", "# Unchanged"]
        let positions = try order.map { title -> String.Index in
            try XCTUnwrap(text.range(of: title)?.lowerBound, "missing \(title)")
        }

        XCTAssertEqual(positions, positions.sorted())
    }

    func testEmptySectionsAreOmitted() {
        let result = ChecksumComparison(metadata: metadata(), added: [entry("a.txt", "aa", 1)])
        let text = ComparisonFileCodec.render(result)

        XCTAssertTrue(text.contains("# Added"))
        XCTAssertFalse(text.contains("# Unchanged"))
        XCTAssertFalse(text.contains("# Changed"))
    }

    func testMetadataCommentsPrecedeEverySection() throws {
        let text = ComparisonFileCodec.render(fullComparison())
        let metadata = try XCTUnwrap(text.range(of: "# csum-second-root /new")?.lowerBound)
        let firstSection = try XCTUnwrap(text.range(of: "# Added")?.lowerBound)

        XCTAssertLessThan(metadata, firstSection)
    }
}
