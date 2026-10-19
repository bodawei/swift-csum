import Foundation

public enum MalformedFileReason: Sendable, Equatable {
    case missingMetadata
    case unparsableAlgorithm
    case unparsableSourceKind(source: String)
    case rowOutsideSections(row: Int)
    case unexpectedColumns(section: String, expected: Int, found: Int)
    case wrongFieldCount(section: String, row: Int, expected: Int, found: Int)
    case unparsableSize(section: String, row: Int)
    case unparsableTimestamp(section: String, row: Int)
    case unparsableOutcome(section: String, row: Int)
    case unterminatedQuote
}

public enum CsumError: Error, Sendable, Equatable {
    case notFound(path: String)
    case sourceUnreadable(path: String)
    case malformedFile(path: String, reason: MalformedFileReason)
    case unsupportedFormatVersion(found: String, expected: String)
    case algorithmMismatch(first: ChecksumAlgorithm, second: ChecksumAlgorithm)
}

extension CsumError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "Nothing found at \(path)."
        case .sourceUnreadable(let path):
            return "Couldn't read \(path). Check that the file is still available and try again."
        case .malformedFile(let path, let reason):
            return "\(path) isn't a valid csum file. \(reason.message)"
        case .unsupportedFormatVersion(let found, let expected):
            return "This file uses csum format \(found), but this version only reads \(expected)."
        case .algorithmMismatch(let first, let second):
            return
                "The files use different algorithms (\(first.displayName) and \(second.displayName)), so they can't be compared."
        }
    }
}

extension MalformedFileReason {
    fileprivate var message: String {
        switch self {
        case .missingMetadata:
            return "It's missing the csum metadata comments."
        case .unparsableAlgorithm:
            return "The recorded checksum algorithm isn't recognised."
        case .unparsableSourceKind(let source):
            return "The recorded source kind “\(source)” isn't recognised."
        case .rowOutsideSections(let row):
            return "Row \(row) doesn't belong to any section."
        case .unexpectedColumns(let section, let expected, let found):
            return
                "The \(section) section has \(found) columns, but \(expected) were expected."
        case .wrongFieldCount(let section, let row, let expected, let found):
            return
                "Row \(row) of the \(section) section has \(found) fields, but \(expected) were expected."
        case .unparsableSize(let section, let row):
            return "Row \(row) of the \(section) section has a size that isn't a number."
        case .unparsableTimestamp(let section, let row):
            return "Row \(row) of the \(section) section has a timestamp that couldn't be read."
        case .unparsableOutcome(let section, let row):
            return
                "Row \(row) of the \(section) section has a checksum outcome that isn't recognised."
        case .unterminatedQuote:
            return "A quoted field is never closed."
        }
    }
}
