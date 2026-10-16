import Foundation

public struct CsvRow: Sendable {
    public var filename = ""
    public var checksum = ""
    public var algorithm = ""
    public var size = ""
    public var created = ""
    public var modified = ""
    public var path = ""

    public init(
        filename: String = "",
        checksum: String = "",
        algorithm: String = "",
        size: String = "",
        created: String = "",
        modified: String = "",
        path: String = ""
    ) {
        self.filename = filename
        self.checksum = checksum
        self.algorithm = algorithm
        self.size = size
        self.created = created
        self.modified = modified
        self.path = path
    }
}

public struct MovedPair: Sendable {
    public let from: CsvRow
    public let to: CsvRow
}

public struct ChangedPair: Sendable {
    public let old: CsvRow
    public let new: CsvRow
}

public struct ComparisonReport: Sendable {
    public var unchanged: [CsvRow] = []
    public var added: [CsvRow] = []
    public var removed: [CsvRow] = []
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

    public static func parse(_ text: String) -> [[String]] {
        var scalars = text.unicodeScalars

        if scalars.first == "\u{FEFF}" {
            scalars.removeFirst()
        }

        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    let next = scalars.index(after: index)

                    if next < scalars.endIndex && scalars[next] == "\"" {
                        field.append(scalar)
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else if scalar == "\"" {
                inQuotes = true
            } else if scalar == "," {
                row.append(String(field))
                field = String.UnicodeScalarView()
            } else if scalar == "\n" || scalar == "\r" {
                row.append(String(field))
                field = String.UnicodeScalarView()
                rows.append(row)
                row = []

                if scalar == "\r" {
                    let next = scalars.index(after: index)

                    if next < scalars.endIndex && scalars[next] == "\n" {
                        index = next
                    }
                }
            } else {
                field.append(scalar)
            }

            index = scalars.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }

        return rows
    }

    public static func rows(from text: String) -> [CsvRow] {
        let fields = parse(text).filter { !$0.isEmpty && !($0.count == 1 && $0[0].isEmpty) }
        let cleaned = fields.filter { !($0.first?.hasPrefix("#") ?? false) }
        let dataRows = cleaned.first?.first == "Filename" ? Array(cleaned.dropFirst()) : cleaned

        return dataRows.map { columns in
            var row = CsvRow()

            if columns.count > 0 { row.filename = columns[0] }

            if columns.count > 1 { row.checksum = columns[1] }

            if columns.count > 2 { row.algorithm = columns[2] }

            if columns.count > 3 { row.size = columns[3] }

            if columns.count > 4 { row.created = columns[4] }

            if columns.count > 5 { row.modified = columns[5] }

            if columns.count > 6 { row.path = columns[6] }

            return row
        }
    }

    public static func compare(first: [CsvRow], second: [CsvRow]) -> ComparisonReport {
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
