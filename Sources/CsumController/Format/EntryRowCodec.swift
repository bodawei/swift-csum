import Foundation

enum EntryColumns {
    static let checksum = "Checksum"
    static let size = "Size"
    static let created = "Created"
    static let modified = "Modified"
    static let path = "Path"

    static let all = [checksum, size, created, modified, path]
}

struct MalformedFile: Error {
    let reason: MalformedFileReason
}

enum EntryRowCodec {
    private static let hexDigits = Set("0123456789abcdefABCDEF")

    static func row(for entry: ChecksumEntry) -> [String] {
        [
            outcomeText(for: entry.outcome),
            String(entry.size),
            timestampText(for: entry.created),
            timestampText(for: entry.modified),
            entry.path
        ]
    }

    static func entry(from row: [String], section: String, rowIndex: Int) throws -> ChecksumEntry {
        guard row.count == EntryColumns.all.count else {
            throw MalformedFile(
                reason: .wrongFieldCount(
                    section: section,
                    row: rowIndex,
                    expected: EntryColumns.all.count,
                    found: row.count
                )
            )
        }

        guard let size = Int64(row[1]) else {
            throw MalformedFile(reason: .unparsableSize(section: section, row: rowIndex))
        }

        return ChecksumEntry(
            path: row[4],
            outcome: try outcome(from: row[0], section: section, rowIndex: rowIndex),
            size: size,
            created: try timestamp(from: row[2], section: section, rowIndex: rowIndex),
            modified: try timestamp(from: row[3], section: section, rowIndex: rowIndex)
        )
    }

    static func outcomeText(for outcome: ChecksumOutcome) -> String {
        switch outcome {
        case .digest(let digest):
            return digest
        case .failure(let code):
            return "!" + token(for: code)
        }
    }

    static func token(for code: ChecksumFailureCode) -> String {
        switch code {
        case .cannotOpen:
            return "cannotOpen"
        case .readFailed:
            return "readFailed"
        }
    }

    static func code(forToken token: String) -> ChecksumFailureCode? {
        switch token {
        case "cannotOpen":
            return .cannotOpen
        case "readFailed":
            return .readFailed
        default:
            return nil
        }
    }

    private static func outcome(from text: String, section: String, rowIndex: Int) throws -> ChecksumOutcome {
        if text.hasPrefix("!") {
            guard let code = code(forToken: String(text.dropFirst())) else {
                throw MalformedFile(reason: .unparsableOutcome(section: section, row: rowIndex))
            }

            return .failure(code)
        }

        guard !text.isEmpty, text.allSatisfy({ hexDigits.contains($0) }) else {
            throw MalformedFile(reason: .unparsableOutcome(section: section, row: rowIndex))
        }

        return .digest(text)
    }

    private static func timestampText(for date: Date?) -> String {
        guard let date else {
            return ""
        }

        return String(Int64(date.timeIntervalSince1970))
    }

    private static func timestamp(from text: String, section: String, rowIndex: Int) throws -> Date? {
        if text.isEmpty {
            return nil
        }

        guard let seconds = Int64(text) else {
            throw MalformedFile(reason: .unparsableTimestamp(section: section, row: rowIndex))
        }

        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}
