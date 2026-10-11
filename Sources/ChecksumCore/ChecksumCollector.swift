import Foundation

public enum ChecksumCollector {
    public static func canonicalPath(for path: String) -> String {
        guard let resolved = realpath(path, nil) else {
            return path
        }
        defer {
            free(resolved)
        }
        return String(cString: resolved)
    }

    public static func collect(url: URL, algorithm: ChecksumAlgorithm) -> [CsvRow] {
        let resolved = url.resolvingSymlinksInPath()
        let isDirectory = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        
        if !isDirectory {
            return [row(for: resolved, base: nil, algorithm: algorithm)]
        }
        
        var base = canonicalPath(for: resolved.path)
        if base.hasSuffix("/") && base.count > 1 {
            base.removeLast()
        }
        return enumerateFiles(in: resolved)
            .sorted { $0.path < $1.path }
            .map { row(for: $0, base: base, algorithm: algorithm) }
    }

    private static func row(for url: URL, base: String?, algorithm: ChecksumAlgorithm) -> CsvRow {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        let checksum: String
        do {
            checksum = try ChecksumCalculator.checksum(of: url, algorithm: algorithm)
        } catch {
            checksum = "Error: \(error.localizedDescription)"
        }
        return CsvRow(
            filename: url.lastPathComponent,
            checksum: checksum,
            algorithm: algorithm.rawValue,
            size: String(Int64(values?.fileSize ?? 0)),
            created: timestampString(values?.creationDate),
            modified: timestampString(values?.contentModificationDate),
            path: displayPath(for: url.path, base: base)
        )
    }

    private static func timestampString(_ date: Date?) -> String {
        date.map { String(Int64($0.timeIntervalSince1970)) } ?? ""
    }

    private static func displayPath(for path: String, base: String?) -> String {
        guard let base else {
            return path
        }
        let prefix = base.hasSuffix("/") ? base : base + "/"
        if path.hasPrefix(prefix) {
            return "./" + String(path.dropFirst(prefix.count))
        }
        return path
    }

    private static func enumerateFiles(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true,
                  values.isDirectory != true else {
                continue
            }
            files.append(url)
        }
        return files
    }
}
