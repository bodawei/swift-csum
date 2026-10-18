import CryptoKit

public enum ChecksumAlgorithm: String, CaseIterable, Sendable {
    case sha256
    case sha1
    case md5

    public var displayName: String {
        switch self {
        case .sha256:
            return "SHA-256"
        case .sha1:
            return "SHA-1"
        case .md5:
            return "MD5"
        }
    }
}
