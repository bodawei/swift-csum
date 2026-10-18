import Foundation

enum EntryCollector {
    private static let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]

    static func entries(
        in folder: URL,
        algorithm: ChecksumAlgorithm,
        progress: (@Sendable (Int, Int) -> Void)?
    ) throws -> [ChecksumEntry] {
        let files = try files(in: folder)
        var entries: [ChecksumEntry] = []

        for index in files.indices {
            entries.append(entry(for: files[index], algorithm: algorithm))
            progress?(index + 1, files.count)
        }

        return entries.sorted { $0.path < $1.path }
    }

    static func entry(for url: URL, algorithm: ChecksumAlgorithm) -> ChecksumEntry {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])

        return ChecksumEntry(
            path: CanonicalPath.of(url.path),
            outcome: outcome(for: url, algorithm: algorithm),
            size: Int64(values?.fileSize ?? 0),
            created: values?.creationDate,
            modified: values?.contentModificationDate
        )
    }

    private static func outcome(for url: URL, algorithm: ChecksumAlgorithm) -> ChecksumOutcome {
        do {
            return .digest(try ChecksumCalculator.checksum(of: url, algorithm: algorithm))
        } catch let error as ChecksumError {
            return .failure(code(for: error))
        } catch {
            return .failure(.readFailed)
        }
    }

    private static func code(for error: ChecksumError) -> ChecksumFailureCode {
        switch error {
        case .cannotOpen:
            return .cannotOpen
        case .readFailed:
            return .readFailed
        }
    }

    private static func files(in folder: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else {
            throw CsumError.sourceUnreadable(path: CanonicalPath.of(folder.path))
        }

        var files: [URL] = []

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true,
                  values.isDirectory != true else {
                continue
            }

            files.append(url)
        }

        return files
    }
}
