import CsumController
import Foundation

enum Format {
    private static let missing = "—"

    static func day(_ date: Date?) -> String {
        guard let date else {
            return missing
        }

        return date.formatted(.dateTime.year().month(.abbreviated).day())
    }

    static func timestamp(_ date: Date?) -> String {
        guard let date else {
            return missing
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func size(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    static func count(_ value: Int) -> String {
        value.formatted()
    }

    static func isolated(_ value: String) -> String {
        "\u{2066}\(value)\u{2069}"
    }

    static func checksum(_ entry: ChecksumEntry) -> String {
        switch entry.outcome {
        case .digest(let digest):
            return digest
        case .failure(let code):
            return failureCode(code)
        }
    }

    private static func failureCode(_ code: ChecksumFailureCode) -> String {
        switch code {
        case .cannotOpen:
            return "!cannotOpen"
        case .readFailed:
            return "!readFailed"
        }
    }
}
