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

        guard isChecksumFile(url) else {
            return try calculateChecksums(at: url)
        }

        return try withScopedAccess(to: url) {
            try ChecksumFileCodec.parse(contentsOf: url)
        }
    }

    public func compare(first firstURL: URL, second secondURL: URL) throws -> ChecksumComparison {
        let comparisonAlgorithm = try resolveAlgorithm(first: firstURL, second: secondURL)
        let comparison = CsumController(algorithm: comparisonAlgorithm, writer: writer)

        let first = try comparison.loadChecksumResult(at: firstURL)
        let second = try comparison.loadChecksumResult(at: secondURL)

        return ComparisonEngine.compare(
            first: first,
            second: second,
            metadata: ComparisonMetadata(
                formatVersion: CsumFormat.version,
                writer: writer,
                toolVersion: CsumFormat.toolVersion,
                computedAt: Date(),
                algorithm: comparisonAlgorithm,
                first: source(for: firstURL, result: first),
                second: source(for: secondURL, result: second)
            )
        )
    }

    private func resolveAlgorithm(first firstURL: URL, second secondURL: URL) throws -> ChecksumAlgorithm {
        let firstRecorded = try recordedAlgorithm(at: firstURL)
        let secondRecorded = try recordedAlgorithm(at: secondURL)

        guard let firstRecorded, let secondRecorded else {
            return firstRecorded ?? secondRecorded ?? algorithm
        }

        guard firstRecorded == secondRecorded else {
            throw CsumError.algorithmMismatch(first: firstRecorded, second: secondRecorded)
        }

        return firstRecorded
    }

    private func recordedAlgorithm(at url: URL) throws -> ChecksumAlgorithm? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CsumError.notFound(path: url.path)
        }

        guard isChecksumFile(url) else {
            return nil
        }

        return try ChecksumFileCodec.parse(contentsOf: url).metadata.algorithm
    }

    private func source(for url: URL, result: ChecksumResult) -> ComparisonSource {
        ComparisonSource(
            path: url.path,
            kind: kind(for: url),
            root: result.metadata.root,
            computedAt: result.metadata.computedAt
        )
    }

    private func kind(for url: URL) -> SourceKind {
        if isChecksumFile(url) {
            return .csumFile
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

        return isDirectory ? .folder : .file
    }

    private func isChecksumFile(_ url: URL) -> Bool {
        url.path.lowercased().hasSuffix(Self.fileSuffix)
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
