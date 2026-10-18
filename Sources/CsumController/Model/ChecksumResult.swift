import Foundation

public struct ChecksumMetadata: Sendable, Equatable {
    public var formatVersion: String
    public var writer: String
    public var toolVersion: String
    public var algorithm: ChecksumAlgorithm
    public var computedAt: Date
    public var root: String

    public init(
        formatVersion: String,
        writer: String,
        toolVersion: String,
        algorithm: ChecksumAlgorithm,
        computedAt: Date,
        root: String
    ) {
        self.formatVersion = formatVersion
        self.writer = writer
        self.toolVersion = toolVersion
        self.algorithm = algorithm
        self.computedAt = computedAt
        self.root = root
    }
}

public struct ChecksumResult: Sendable, Equatable {
    public var metadata: ChecksumMetadata
    public var entries: [ChecksumEntry]

    public init(metadata: ChecksumMetadata, entries: [ChecksumEntry]) {
        self.metadata = metadata
        self.entries = entries
    }

    public func relativePath(of entry: ChecksumEntry) -> String {
        CanonicalPath.relativePath(of: entry.path, root: metadata.root)
    }
}
