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

        var pool = Dictionary(
            grouping: remaining.sorted(),
            by: { pairingKey(for: second.entries[$0]) }
        ).mapValues { Bucket(indices: $0) }

        var removed: [ChecksumEntry] = []

        for entry in unmatched {
            let poolKey = pairingKey(for: entry)

            guard var bucket = pool[poolKey], !bucket.isEmpty else {
                removed.append(entry)
                continue
            }

            let index = bucket.take()
            pool[poolKey] = bucket
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

    private struct Bucket {
        let indices: [Int]
        var next = 0

        var isEmpty: Bool {
            next == indices.count
        }

        mutating func take() -> Int {
            defer {
                next += 1
            }

            return indices[next]
        }
    }

    private static func pairingKey(for entry: ChecksumEntry) -> String {
        let content = "\(EntryRowCodec.outcomeText(for: entry.outcome))\u{1F}\(entry.size)"

        guard entry.size == 0 else {
            return content
        }

        return content + "\u{1F}" + EntryRowCodec.timestampText(for: entry.created)
    }

    private static func parentDirectory(of path: String) -> String {
        (path as NSString).deletingLastPathComponent
    }
}
