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

        let digest: String

        switch algorithm {
        case .sha256:
            digest = try digestHex(SHA256(), handle: handle, path: path)
        case .sha1:
            digest = try digestHex(Insecure.SHA1(), handle: handle, path: path)
        case .md5:
            digest = try digestHex(Insecure.MD5(), handle: handle, path: path)
        }

        return digest
    }

    private static func digestHex<H: HashFunction>(
        _ hasher: H,
        handle: FileHandle,
        path: String
    ) throws -> String {
        var hasher = hasher

        try updateHasher(&hasher, withContentsOf: handle, path: path)

        return hexString(of: hasher.finalize())
    }

    private static func updateHasher<H: HashFunction>(
        _ hasher: inout H,
        withContentsOf handle: FileHandle,
        path: String
    ) throws {
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
