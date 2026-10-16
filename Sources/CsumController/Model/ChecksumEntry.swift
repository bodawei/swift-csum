import Foundation

public enum ChecksumFailureCode: Sendable, Equatable, Hashable {
    case cannotOpen
    case readFailed
}

public enum ChecksumOutcome: Sendable, Equatable, Hashable {
    case digest(String)
    case failure(ChecksumFailureCode)
}

public struct ChecksumEntry: Sendable, Equatable, Hashable {
    public var path: String
    public var outcome: ChecksumOutcome
    public var size: Int64
    public var created: Date?
    public var modified: Date?

    public init(
        path: String,
        outcome: ChecksumOutcome,
        size: Int64,
        created: Date? = nil,
        modified: Date? = nil
    ) {
        self.path = path
        self.outcome = outcome
        self.size = size
        self.created = created
        self.modified = modified
    }
}
