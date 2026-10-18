import Foundation

public struct MatchedEntry: Sendable, Equatable, Hashable {
    public var old: ChecksumEntry
    public var new: ChecksumEntry

    public init(old: ChecksumEntry, new: ChecksumEntry) {
        self.old = old
        self.new = new
    }
}

public enum SourceKind: String, Sendable {
    case file
    case folder
    case csumFile
}

public struct ComparisonSource: Sendable, Equatable {
    public var path: String
    public var kind: SourceKind
    public var root: String
    public var computedAt: Date

    public init(path: String, kind: SourceKind, root: String, computedAt: Date) {
        self.path = path
        self.kind = kind
        self.root = root
        self.computedAt = computedAt
    }

    public func relativePath(of entry: ChecksumEntry) -> String {
        CanonicalPath.relativePath(of: entry.path, root: root)
    }
}

public struct ComparisonMetadata: Sendable, Equatable {
    public var formatVersion: String
    public var writer: String
    public var toolVersion: String
    public var computedAt: Date
    public var algorithm: ChecksumAlgorithm
    public var first: ComparisonSource
    public var second: ComparisonSource

    public init(
        formatVersion: String,
        writer: String,
        toolVersion: String,
        computedAt: Date,
        algorithm: ChecksumAlgorithm,
        first: ComparisonSource,
        second: ComparisonSource
    ) {
        self.formatVersion = formatVersion
        self.writer = writer
        self.toolVersion = toolVersion
        self.computedAt = computedAt
        self.algorithm = algorithm
        self.first = first
        self.second = second
    }
}

public struct ChecksumComparison: Sendable, Equatable {
    public var metadata: ComparisonMetadata
    public var unchanged: [ChecksumEntry]
    public var added: [ChecksumEntry]
    public var removed: [ChecksumEntry]
    public var changed: [MatchedEntry]
    public var moved: [MatchedEntry]
    public var renamed: [MatchedEntry]

    public init(
        metadata: ComparisonMetadata,
        unchanged: [ChecksumEntry] = [],
        added: [ChecksumEntry] = [],
        removed: [ChecksumEntry] = [],
        changed: [MatchedEntry] = [],
        moved: [MatchedEntry] = [],
        renamed: [MatchedEntry] = []
    ) {
        self.metadata = metadata
        self.unchanged = unchanged
        self.added = added
        self.removed = removed
        self.changed = changed
        self.moved = moved
        self.renamed = renamed
    }
}

public enum ComparisonSection: String, CaseIterable, Sendable {
    case added
    case removed
    case changed
    case moved
    case renamed
    case unchanged
}
