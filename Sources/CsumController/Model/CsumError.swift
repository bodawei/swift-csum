import Foundation

public enum MalformedFileReason: Sendable, Equatable {
    case missingMetadata
    case unexpectedColumns(section: String, expected: Int, found: Int)
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
