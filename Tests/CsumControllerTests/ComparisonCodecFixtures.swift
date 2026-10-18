import XCTest

@testable import CsumController

class ComparisonCodecTestCase: XCTestCase {
    let computedAt = Date(timeIntervalSince1970: 1_750_000_000)
    let earlier = Date(timeIntervalSince1970: 1_749_900_000)

    func entry(_ path: String, _ digest: String, _ size: Int64) -> ChecksumEntry {
        ChecksumEntry(path: path, outcome: .digest(digest), size: size)
    }

    func metadata(firstRoot: String = "/old", secondRoot: String = "/new") -> ComparisonMetadata {
        ComparisonMetadata(
            formatVersion: CsumFormat.version,
            writer: CsumController.cliWriter,
            toolVersion: CsumFormat.toolVersion,
            computedAt: computedAt,
            algorithm: .sha256,
            first: ComparisonSource(
                path: "/old.csum.csv", kind: .csumFile, root: firstRoot, computedAt: computedAt),
            second: ComparisonSource(
                path: "/new", kind: .folder, root: secondRoot, computedAt: earlier)
        )
    }

    func fullComparison(root: String = "") -> ChecksumComparison {
        ChecksumComparison(
            metadata: metadata(firstRoot: "/old\(root)", secondRoot: "/new\(root)"),
            unchanged: [entry("/new\(root)/keep.txt", "aa", 1)],
            added: [entry("/new\(root)/added.txt", "bb", 2)],
            removed: [entry("/old\(root)/removed.txt", "cc", 3)],
            changed: [
                MatchedEntry(
                    old: entry("/old\(root)/changed.txt", "dd", 4),
                    new: entry("/new\(root)/changed.txt", "ee", 5)
                )
            ],
            moved: [
                MatchedEntry(
                    old: entry("/old\(root)/moved/f.txt", "ff", 6),
                    new: entry("/new\(root)/elsewhere/f.txt", "ff", 6)
                )
            ],
            renamed: [
                MatchedEntry(
                    old: entry("/old\(root)/sub/g.txt", "11", 7),
                    new: entry("/new\(root)/sub/h.txt", "11", 7)
                )
            ]
        )
    }

    func comparison(added: [ChecksumEntry], changed: [MatchedEntry]) -> ChecksumComparison {
        ChecksumComparison(metadata: metadata(), added: added, changed: changed)
    }

    func document(
        format: String = "1.0",
        kind: String = "folder",
        computed: String = "2025-06-15T15:06:40Z",
        body: [String] = []
    ) -> String {
        let lines =
            [
                "\u{FEFF}# csum-format \(format)",
                "# csum-writer csum-cli 1.0",
                "# csum-computed 2025-06-15T15:06:40Z",
                "# csum-algorithm sha256",
                "# csum-first-path /old",
                "# csum-first-kind \(kind)",
                "# csum-first-root /old",
                "# csum-first-computed \(computed)",
                "# csum-second-path /new",
                "# csum-second-kind folder",
                "# csum-second-root /new",
                "# csum-second-computed 2025-06-15T15:06:40Z",
            ] + body

        return lines.joined(separator: "\r\n") + "\r\n"
    }
}
