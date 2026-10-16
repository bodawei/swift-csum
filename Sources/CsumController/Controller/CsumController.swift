import Foundation

public struct CsumController: Sendable {
    public static let cliWriter = "csum-cli"
    public static let appWriter = "csum"

    private static let fileSuffix = ".csum.csv"

    private let algorithm: ChecksumAlgorithm
    private let writer: String

    public init(algorithm: ChecksumAlgorithm, writer: String) {
        self.algorithm = algorithm
        self.writer = writer
    }

    public func calculateChecksums(
        at url: URL,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> ChecksumResult {
        let entries = try withScopedAccess(to: url) {
            try collectEntries(at: url, progress: progress)
        }

        return ChecksumResult(
            metadata: ChecksumMetadata(
                formatVersion: CsumFormat.version,
                writer: writer,
                toolVersion: CsumFormat.toolVersion,
                algorithm: algorithm,
                computedAt: Date(),
                root: CanonicalPath.of(url.path)
            ),
            entries: entries
        )
    }

    public func loadChecksumResult(at url: URL) throws -> ChecksumResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CsumError.notFound(path: url.path)
        }

        guard url.path.lowercased().hasSuffix(Self.fileSuffix) else {
            return try calculateChecksums(at: url)
        }

        return try withScopedAccess(to: url) {
            try ChecksumFileCodec.parse(contentsOf: url)
        }
    }

    private func collectEntries(
        at url: URL,
        progress: (@Sendable (Int, Int) -> Void)?
    ) throws -> [ChecksumEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CsumError.notFound(path: url.path)
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

        if isDirectory {
            return try EntryCollector.entries(in: url, algorithm: algorithm, progress: progress)
        }

        progress?(1, 1)

        return [EntryCollector.entry(for: url, algorithm: algorithm)]
    }

    private func withScopedAccess<T>(to url: URL, _ body: () throws -> T) rethrows -> T {
        let accessed = url.startAccessingSecurityScopedResource()

        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try body()
    }
}
