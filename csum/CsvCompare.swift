import Foundation

struct CsvRow: Sendable {
    var filename = ""
    var checksum = ""
    var algorithm = ""
    var size = ""
    var created = ""
    var modified = ""
    var path = ""
}

struct MovedPair: Sendable {
    let from: CsvRow
    let to: CsvRow
}

struct ChangedPair: Sendable {
    let old: CsvRow
    let new: CsvRow
}

struct ComparisonReport: Sendable {
    var unchanged: [CsvRow] = []
    var added: [CsvRow] = []
    var removed: [CsvRow] = []
    var moved: [MovedPair] = []
    var changed: [ChangedPair] = []

    var isEmpty: Bool {
        unchanged.isEmpty && added.isEmpty && removed.isEmpty && moved.isEmpty && changed.isEmpty
    }
}

enum CsvCompare {
    static func parse(_ text: String) -> [[String]] {
        var characters = text
        if characters.hasPrefix("\u{FEFF}") {
            characters.removeFirst()
        }
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = characters.startIndex
        while index < characters.endIndex {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    let next = characters.index(after: index)
                    if next < characters.endIndex && characters[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                row.append(field)
                field = ""
            } else if character == "\n" {
                row.append(field)
                field = ""
                rows.append(row)
                row = []
            } else if character != "\r" {
                field.append(character)
            }
            index = characters.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    static func rows(from text: String) -> [CsvRow] {
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

    static func compare(first: [CsvRow], second: [CsvRow]) -> ComparisonReport {
        var report = ComparisonReport()
        var byPath = Dictionary(grouping: second, by: { $0.path })
        var movePool = Dictionary(grouping: second, by: { "\($0.checksum)\u{1F}\($0.size)" })
        var consumedPaths = Set<String>()

        for row in first {
            if var candidates = byPath[row.path], let match = candidates.first {
                candidates.removeFirst()
                byPath[row.path] = candidates.isEmpty ? nil : candidates
                consumedPaths.insert(match.path)
                if match.checksum == row.checksum && match.size == row.size {
                    report.unchanged.append(match)
                } else {
                    report.changed.append(ChangedPair(old: row, new: match))
                }
            } else if var pool = movePool["\(row.checksum)\u{1F}\(row.size)"], let target = pool.first {
                pool.removeFirst()
                let key = "\(row.checksum)\u{1F}\(row.size)"
                movePool[key] = pool.isEmpty ? nil : pool
                consumedPaths.insert(target.path)
                report.moved.append(MovedPair(from: row, to: target))
            } else {
                report.removed.append(row)
            }
        }

        for row in second where !consumedPaths.contains(row.path) {
            report.added.append(row)
        }

        report.unchanged.sort { $0.path < $1.path }
        report.added.sort { $0.path < $1.path }
        report.removed.sort { $0.path < $1.path }
        report.moved.sort { $0.to.path < $1.to.path }
        report.changed.sort { $0.old.path < $1.old.path }
        return report
    }
}
