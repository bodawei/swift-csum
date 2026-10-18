#if DEBUG
    import CsumController
    import Foundation

    struct DemoService: Checksumming {
        func checksum(
            at url: URL,
            progress: @escaping @Sendable (Int, Int) -> Void
        ) async throws -> ChecksumResult {
            let entries = url.hasDirectoryPath ? DemoData.folderEntries : DemoData.fileEntries

            for index in entries.indices {
                progress(index + 1, entries.count)

                if index % 8 == 0 {
                    try? await Task.sleep(for: .milliseconds(2))
                }
            }

            return ChecksumResult(
                metadata: ChecksumMetadata(
                    formatVersion: CsumFormat.version,
                    writer: CsumController.appWriter,
                    toolVersion: CsumFormat.toolVersion,
                    algorithm: .sha256,
                    computedAt: DemoData.computedAt,
                    root: url.path
                ),
                entries: entries
            )
        }

        func compare(first: URL, second: URL) async throws -> ChecksumComparison {
            DemoData.comparison
        }
    }

    enum DemoData {
        static let fileURL = URL(fileURLWithPath: "/Users/demo/Documents/archive.zip")
        static let folderURL = URL(fileURLWithPath: "/Users/demo/Pictures/2026", isDirectory: true)
        static let copiedFolderURL = URL(
            fileURLWithPath: "/Users/demo/Pictures/2026-copy",
            isDirectory: true
        )

        static let computedAt = Date(timeIntervalSince1970: 1_760_000_000)

        static let fileEntries = [
            entry(
                "/Users/demo/Documents/archive.zip",
                digest(1),
                12_400_000
            )
        ]

        static let folderEntries: [ChecksumEntry] = [
            entry("/Users/demo/Pictures/2026/2026-07/IMG_1042.HEIC", digest(2), 3_800_000),
            entry("/Users/demo/Pictures/2026/2026-07/IMG_1043.HEIC", digest(3), 4_100_000),
            entry("/Users/demo/Pictures/2026/2026-08/IMG_1101.HEIC", digest(4), 3_200_000),
            entry("/Users/demo/Pictures/2026/2026-08/notes.txt", digest(5), 1_200),
            entry("/Users/demo/Pictures/2026/2026-09/DSC_0117.NEF", digest(6), 48_600_000),
            entry("/Users/demo/Pictures/2026/2026-09/DSC_0118.NEF", digest(7), 47_900_000),
            entry("/Users/demo/Pictures/2026/2026-10/scan-0001.pdf", digest(8), 812_000),
            entry("/Users/demo/Pictures/2026/2026-10/scan-0002.pdf", digest(9), 798_000),
        ]

        static let comparison: ChecksumComparison = {
            let root = folderURL.path
            let copy = copiedFolderURL.path

            return ChecksumComparison(
                metadata: ComparisonMetadata(
                    formatVersion: CsumFormat.version,
                    writer: CsumController.appWriter,
                    toolVersion: CsumFormat.toolVersion,
                    computedAt: computedAt,
                    algorithm: .sha256,
                    first: ComparisonSource(
                        path: root,
                        kind: .folder,
                        root: root,
                        computedAt: computedAt.addingTimeInterval(-3_600)
                    ),
                    second: ComparisonSource(
                        path: copy,
                        kind: .folder,
                        root: copy,
                        computedAt: computedAt
                    )
                ),
                unchanged: [
                    entry("\(root)/2026-08/notes.txt", digest(5), 1_200),
                    entry("\(root)/2026-09/DSC_0117.NEF", digest(6), 48_600_000),
                    entry("\(root)/2026-09/DSC_0118.NEF", digest(7), 47_900_000),
                ],
                added: [
                    entry("\(copy)/2026-10/scan-0003.pdf", digest(10), 812_000),
                    entry("\(copy)/2026-10/scan-0004.pdf", digest(11), 798_000),
                ],
                removed: [
                    entry("\(root)/2026-10/scan-0002.pdf", digest(9), 798_000)
                ],
                changed: [
                    MatchedEntry(
                        old: entry("\(root)/2026-09/IMG_1100.HEIC", digest(12), 3_200_000),
                        new: entry("\(copy)/2026-09/IMG_1100.HEIC", digest(13), 3_200_000)
                    )
                ],
                moved: [
                    MatchedEntry(
                        old: entry("\(root)/2026-08/IMG_1101.HEIC", digest(4), 3_200_000),
                        new: entry("\(copy)/2026-08/archive/IMG_1101.HEIC", digest(4), 3_200_000)
                    )
                ],
                renamed: [
                    MatchedEntry(
                        old: entry("\(root)/2026-10/scan-0001.pdf", digest(8), 812_000),
                        new: entry("\(copy)/2026-10/scan-0001-final.pdf", digest(8), 812_000)
                    )
                ]
            )
        }()

        private static func entry(
            _ path: String,
            _ checksum: String,
            _ size: Int64,
            created: Date = Date(timeIntervalSince1970: 1_759_000_000),
            modified: Date = Date(timeIntervalSince1970: 1_759_900_000)
        ) -> ChecksumEntry {
            ChecksumEntry(
                path: path,
                outcome: .digest(checksum),
                size: size,
                created: created,
                modified: modified
            )
        }

        private static func digest(_ value: Int) -> String {
            var seed = UInt64(value) &* 0x9E37_79B9_7F4A_7C15
            var parts: [String] = []

            for _ in 0..<4 {
                seed ^= seed >> 30
                seed = seed &* 0xBF58_476D_1CE4_E5B9
                seed ^= seed >> 27
                seed = seed &* 0x94D0_49BB_1331_11EB
                seed ^= seed >> 31
                parts.append(String(format: "%016llx", seed))
            }

            return parts.joined()
        }
    }
#endif
