import Foundation

public struct MovedPair: Sendable {
    public let from: CsumCsvDataRow
    public let to: CsumCsvDataRow
}

public struct ChangedPair: Sendable {
    public let old: CsumCsvDataRow
    public let new: CsumCsvDataRow
}

public struct ComparisonReport: Sendable {
    public var unchanged: [CsumCsvDataRow] = []
    public var added: [CsumCsvDataRow] = []
    public var removed: [CsumCsvDataRow] = []
    public var moved: [MovedPair] = []
    public var renamed: [MovedPair] = []
    public var changed: [ChangedPair] = []

    public var isEmpty: Bool {
        unchanged.isEmpty && added.isEmpty && removed.isEmpty && moved.isEmpty && renamed.isEmpty && changed.isEmpty
    }
}

public enum CsvCompare {
    public static func loadRows(url: URL, algorithm: ChecksumAlgorithm) throws -> [CsvRow] {
        if url.path.lowercased().hasSuffix(".csum.csv") {
            let data = try Data(contentsOf: url)

            return rows(from: String(decoding: data, as: UTF8.self))
        }

        return ChecksumCollector.collect(url: url, algorithm: algorithm)
    }

    public static func rows(from text: String) -> [CsumCsvDataRow] {
        guard var table = try? Csv.parse(
            text,
            options: CsvOptions(dataFormat: .excel, allowLineComments: true)
        ) else {
            return []
        }

        if table.rows.first?.first == ChecksumColumns.filename {
            table.columns = table.rows.removeFirst()
        }

        return table.checksumRows
    }

    public static func compare(first: [CsumCsvDataRow], second: [CsumCsvDataRow]) -> ComparisonReport {
        var report = ComparisonReport()
        var byPath = Dictionary(grouping: second.indices, by: { second[$0].path })
        var remaining = Set(second.indices)
        var unmatchedFirst: [CsvRow] = []

        for row in first {
            if var candidates = byPath[row.path], let index = candidates.first {
                candidates.removeFirst()
                byPath[row.path] = candidates.isEmpty ? nil : candidates
                remaining.remove(index)

                let match = second[index]

                if match.checksum == row.checksum && match.size == row.size {
                    report.unchanged.append(match)
                } else {
                    report.changed.append(ChangedPair(old: row, new: match))
                }
            } else {
                unmatchedFirst.append(row)
            }
        }

        var movePool = Dictionary(grouping: remaining, by: { matchKey(for: second[$0]) })

        for row in unmatchedFirst {
            let key = matchKey(for: row)

            guard var candidates = movePool[key], let index = candidates.first else {
                report.removed.append(row)
                continue
            }

            candidates.removeFirst()
            movePool[key] = candidates.isEmpty ? nil : candidates
            remaining.remove(index)

            let pair = MovedPair(from: row, to: second[index])

            if parentDirectory(of: row.path) == parentDirectory(of: second[index].path) {
                report.renamed.append(pair)
            } else {
                report.moved.append(pair)
            }
        }

        report.added = remaining.sorted().map { second[$0] }

        report.unchanged.sort { $0.path < $1.path }
        report.added.sort { $0.path < $1.path }
        report.removed.sort { $0.path < $1.path }
        report.moved.sort { $0.to.path < $1.to.path }
        report.renamed.sort { $0.to.path < $1.to.path }
        report.changed.sort { $0.old.path < $1.old.path }

        return report
    }

    private static func matchKey(for row: CsvRow) -> String {
        "\(row.checksum)\u{1F}\(row.size)"
    }

    private static func parentDirectory(of path: String) -> String {
        (path as NSString).deletingLastPathComponent
    }
}
