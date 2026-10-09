import CryptoKit
import Foundation

public enum ChecksumError: Error {
    case cannotOpen(path: String, underlying: Error)
    case readFailed(path: String, underlying: Error)
}

extension ChecksumError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let path, let underlying):
            return "Cannot open \(path): \(underlying.localizedDescription)"
        case .readFailed(let path, let underlying):
            return "Failed while reading \(path): \(underlying.localizedDescription)"
        }
    }
}

public enum ChecksumCalculator {
    private static let chunkSize = 1 << 20

    public static func checksum(of url: URL, algorithm: ChecksumAlgorithm) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw ChecksumError.cannotOpen(path: url.path, underlying: error)
        }
        defer {
            try? handle.close()
        }
        let path = url.path
        switch algorithm {
        case .sha256:
            var hasher = SHA256()
            try update(&hasher, with: handle, path: path)
            return hexString(of: hasher.finalize())
        case .sha1:
            var hasher = Insecure.SHA1()
            try update(&hasher, with: handle, path: path)
            return hexString(of: hasher.finalize())
        case .md5:
            var hasher = Insecure.MD5()
            try update(&hasher, with: handle, path: path)
            return hexString(of: hasher.finalize())
        }
    }

    private static func update<H: HashFunction>(_ hasher: inout H, with handle: FileHandle, path: String) throws {
        while true {
            let chunk: Data?
            do {
                chunk = try handle.read(upToCount: chunkSize)
            } catch {
                throw ChecksumError.readFailed(path: path, underlying: error)
            }
            guard let chunk, !chunk.isEmpty else {
                return
            }
            hasher.update(data: chunk)
        }
    }

    private static func hexString<D: Digest>(of digest: D) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
