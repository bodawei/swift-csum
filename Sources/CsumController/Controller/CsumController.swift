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
        progress: (@Sendable (Int, Int) -> Void)? = nil,
        isCancelled: (@Sendable () -> Bool)? = nil
    ) throws -> ChecksumResult {
        try withScopedAccess(to: url) {
            try calculateChecksumsUnscoped(at: url, progress: progress, isCancelled: isCancelled)
        }
    }

    public func loadChecksumResult(
        at url: URL,
        isCancelled: (@Sendable () -> Bool)? = nil
    ) throws -> ChecksumResult {
        try withScopedAccess(to: url) {
            try loadChecksumResultUnscoped(at: url, isCancelled: isCancelled)
        }
    }

    public func compare(
        first firstURL: URL,
        second secondURL: URL,
        isCancelled: (@Sendable () -> Bool)? = nil
    ) throws -> ChecksumComparison {
        try withScopedAccess(to: firstURL) {
            try withScopedAccess(to: secondURL) {
                try compareUnscoped(first: firstURL, second: secondURL, isCancelled: isCancelled)
            }
        }
    }

    private func calculateChecksumsUnscoped(
        at url: URL,
        progress: (@Sendable (Int, Int) -> Void)?,
        isCancelled: (@Sendable () -> Bool)?
    ) throws -> ChecksumResult {
        try Telemetry.span(
            named: "csum.calculateChecksums",
            attributes: [
                Telemetry.Keys.algorithm: .string(algorithm.rawValue),
                Telemetry.Keys.path: .string(url.path),
            ]
        ) { span in
            let entries = try collectEntries(at: url, progress: progress, isCancelled: isCancelled)

            span.setAttribute(key: Telemetry.Keys.entryCount, value: entries.count)

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
    }

    private func loadChecksumResultUnscoped(
        at url: URL,
        isCancelled: (@Sendable () -> Bool)?
    ) throws -> ChecksumResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CsumError.notFound(path: url.path)
        }

        guard isChecksumFile(url) else {
            return try calculateChecksumsUnscoped(
                at: url, progress: nil, isCancelled: isCancelled)
        }

        return try ChecksumFileCodec.parse(contentsOf: url)
    }

    private func compareUnscoped(
        first firstURL: URL,
        second secondURL: URL,
        isCancelled: (@Sendable () -> Bool)?
    ) throws -> ChecksumComparison {
        try Telemetry.span(
            named: "csum.compare",
            attributes: [
                Telemetry.Keys.firstPath: .string(firstURL.path),
                Telemetry.Keys.secondPath: .string(secondURL.path),
            ]
        ) { span in
            let comparisonAlgorithm = try resolveAlgorithm(first: firstURL, second: secondURL)
            let comparison = CsumController(algorithm: comparisonAlgorithm, writer: writer)

            let first = try comparison.loadChecksumResultUnscoped(
                at: firstURL, isCancelled: isCancelled)
            let second = try comparison.loadChecksumResultUnscoped(
                at: secondURL, isCancelled: isCancelled)

            let result = ComparisonEngine.compare(
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

            span.setAttributes([
                Telemetry.Keys.algorithm: .string(comparisonAlgorithm.rawValue),
                Telemetry.Keys.unchangedCount: .int(result.unchanged.count),
                Telemetry.Keys.changedCount: .int(result.changed.count),
                Telemetry.Keys.addedCount: .int(result.added.count),
                Telemetry.Keys.removedCount: .int(result.removed.count),
                Telemetry.Keys.movedCount: .int(result.moved.count),
                Telemetry.Keys.renamedCount: .int(result.renamed.count),
            ])

            return result
        }
    }

    private func resolveAlgorithm(first firstURL: URL, second secondURL: URL) throws
        -> ChecksumAlgorithm
    {
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
        progress: (@Sendable (Int, Int) -> Void)?,
        isCancelled: (@Sendable () -> Bool)?
    ) throws -> [ChecksumEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CsumError.notFound(path: url.path)
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

        if isDirectory {
            return try EntryCollector.entries(
                in: url,
                algorithm: algorithm,
                progress: progress,
                isCancelled: isCancelled
            )
        }

        if isCancelled?() == true {
            throw CancellationError()
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
