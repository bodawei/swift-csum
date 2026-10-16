import Foundation

public enum ChecksumCollector {
    private static func canonicalPath(for path: String) -> String {
        guard let resolved = realpath(path, nil) else {
            return path
        }

        defer {
            free(resolved)
        }

        return String(cString: resolved)
    }

    public static func collect(url: URL, algorithm: ChecksumAlgorithm) -> [CsumCsvDataRow] {
        let resolved = url.resolvingSymlinksInPath()
        let isDirectory = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

        if !isDirectory {
            return [makeRow(for: resolved, base: nil, algorithm: algorithm)]
        }

        var base = canonicalPath(for: resolved.path)

        if base.hasSuffix("/") && base.count > 1 {
            base.removeLast()
        }

        return enumerateFiles(in: resolved)
            .sorted { $0.path < $1.path }
            .map { makeRow(for: $0, base: base, algorithm: algorithm) }
    }

    public static func collectAll(
        urls: [URL],
        algorithm: ChecksumAlgorithm,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> [CsumCsvDataRow] {
        var accessed: [URL] = []

        do {
            var files: [(url: URL, base: String?)] = []

            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    accessed.append(url)
                }

                let resolved = url.resolvingSymlinksInPath()
                let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])

                if values.isSymbolicLink == true {
                    continue
                }

                if values.isDirectory == true {
                    var base = canonicalPath(for: resolved.path)

                    if base.hasSuffix("/") && base.count > 1 {
                        base.removeLast()
                    }

                    for file in enumerateFiles(in: resolved) {
                        files.append((file, base))
                    }
                } else {
                    files.append((url, nil))
                }
            }

            let sorted = files.sorted { $0.url.path < $1.url.path }
            var rows: [CsumCsvDataRow] = []

            for index in sorted.indices {
                rows.append(makeRow(for: sorted[index].url, base: sorted[index].base, algorithm: algorithm))
                progress?(index + 1, sorted.count)
            }

            for url in accessed {
                url.stopAccessingSecurityScopedResource()
            }

            return rows
        } catch {
            for url in accessed {
                url.stopAccessingSecurityScopedResource()
            }

            throw error
        }
    }

    private static func makeRow(for url: URL, base: String?, algorithm: ChecksumAlgorithm) -> CsumCsvDataRow {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        let checksum: String

        do {
            checksum = try ChecksumCalculator.checksum(of: url, algorithm: algorithm)
        } catch {
            checksum = "Error: \(error.localizedDescription)"
        }

        return CsumCsvDataRow(
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
