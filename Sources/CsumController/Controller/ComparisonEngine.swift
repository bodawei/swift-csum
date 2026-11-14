import Foundation

enum ComparisonEngine {
    static func compare(
        first: ChecksumResult,
        second: ChecksumResult,
        metadata: ComparisonMetadata
    ) -> ChecksumComparison {
        var unchanged: [ChecksumEntry] = []
        var changed: [MatchedEntry] = []
        var moved: [MatchedEntry] = []
        var renamed: [MatchedEntry] = []
        var unmatched: [ChecksumEntry] = []

        var remaining = Set(second.entries.indices)
        var byPath = Dictionary(
            grouping: second.entries.indices,
            by: {
                CanonicalPath.relativePath(of: second.entries[$0].path, root: second.metadata.root)
            }
        )

        for entry in first.entries {
            let key = CanonicalPath.relativePath(of: entry.path, root: first.metadata.root)

            guard var candidates = byPath[key], let index = candidates.first else {
                unmatched.append(entry)
                continue
            }

            candidates.removeFirst()
            byPath[key] = candidates.isEmpty ? nil : candidates
            remaining.remove(index)

            let match = second.entries[index]

            if match.outcome == entry.outcome && match.size == entry.size {
                unchanged.append(match)
            } else {
                changed.append(MatchedEntry(old: entry, new: match))
            }
        }

        var pool: [String: [Int]] = [:]

        for index in remaining.sorted() {
            pool[contentKey(for: second.entries[index]), default: []].append(index)
        }

        var removed: [ChecksumEntry] = []

        for entry in unmatched {
            let poolKey = contentKey(for: entry)

            guard var candidates = pool[poolKey],
                let position = candidatePosition(
                    for: entry, among: candidates, in: second.entries)
            else {
                removed.append(entry)
                continue
            }

            let index = candidates.remove(at: position)
            pool[poolKey] = candidates.isEmpty ? nil : candidates
            remaining.remove(index)

            let pair = MatchedEntry(old: entry, new: second.entries[index])

            if parentDirectory(
                of: CanonicalPath.relativePath(of: entry.path, root: first.metadata.root))
                == parentDirectory(
                    of: CanonicalPath.relativePath(
                        of: second.entries[index].path, root: second.metadata.root))
            {
                renamed.append(pair)
            } else {
                moved.append(pair)
            }
        }

        return ChecksumComparison(
            metadata: metadata,
            unchanged: unchanged.sorted { $0.path < $1.path },
            added: remaining.sorted().map { second.entries[$0] },
            removed: removed.sorted { $0.path < $1.path },
            changed: changed.sorted { $0.old.path < $1.old.path },
            moved: moved.sorted { $0.new.path < $1.new.path },
            renamed: renamed.sorted { $0.new.path < $1.new.path }
        )
    }

    private static func contentKey(for entry: ChecksumEntry) -> String {
        "\(EntryRowCodec.outcomeText(for: entry.outcome))\u{1F}\(entry.size)"
    }

    private static func candidatePosition(
        for entry: ChecksumEntry,
        among candidates: [Int],
        in entries: [ChecksumEntry]
    ) -> Int? {
        guard entry.size == 0, let created = entry.created else {
            return candidates.isEmpty ? nil : 0
        }

        let stamp = EntryRowCodec.timestampText(for: created)

        let dated = candidates.firstIndex {
            entries[$0].created.map { EntryRowCodec.timestampText(for: $0) == stamp } ?? false
        }

        return dated ?? candidates.firstIndex { entries[$0].created == nil }
    }

    private static func parentDirectory(of path: String) -> String {
        (path as NSString).deletingLastPathComponent
    }
}
