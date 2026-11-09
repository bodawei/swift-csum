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
        let descriptor = try openDescriptor(for: url)

        defer {
            close(descriptor)
        }

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: chunkSize, alignment: 16)

        defer {
            buffer.deallocate()
        }

        switch algorithm {
        case .sha256:
            return try digestHex(SHA256(), descriptor: descriptor, buffer: buffer, path: url.path)
        case .sha1:
            return try digestHex(
                Insecure.SHA1(), descriptor: descriptor, buffer: buffer, path: url.path)
        case .md5:
            return try digestHex(
                Insecure.MD5(), descriptor: descriptor, buffer: buffer, path: url.path)
        }
    }

    private static func openDescriptor(for url: URL) throws -> Int32 {
        let (descriptor, code) = url.withUnsafeFileSystemRepresentation {
            path -> (Int32, Int32) in
            guard let path else {
                return (-1, EINVAL)
            }

            let descriptor = open(path, O_RDONLY | O_CLOEXEC)

            return (descriptor, descriptor >= 0 ? 0 : errno)
        }

        guard descriptor >= 0 else {
            throw ChecksumError.cannotOpen(
                path: url.path,
                underlying: POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
            )
        }

        return descriptor
    }

    private static func digestHex<H: HashFunction>(
        _ hasher: H,
        descriptor: Int32,
        buffer: UnsafeMutableRawPointer,
        path: String
    ) throws -> String {
        var hasher = hasher

        try updateHasher(&hasher, withContentsOf: descriptor, buffer: buffer, path: path)

        return hexString(of: hasher.finalize())
    }

    private static func updateHasher<H: HashFunction>(
        _ hasher: inout H,
        withContentsOf descriptor: Int32,
        buffer: UnsafeMutableRawPointer,
        path: String
    ) throws {
        while true {
            let count = read(descriptor, buffer, chunkSize)

            if count < 0 {
                let code = errno

                if code == EINTR {
                    continue
                }

                throw ChecksumError.readFailed(
                    path: path,
                    underlying: POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
                )
            }

            guard count > 0 else {
                return
            }

            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: count))
        }
    }

    private static func hexString<D: Digest>(of digest: D) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
