import CryptoKit
import Foundation
@testable import CsumController

final class TempTree {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("csum-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    var root: String {
        canonical(url)
    }

    func canonical(_ url: URL) -> String {
        CanonicalPath.of(url.path)
    }

    func path(_ relativePath: String) -> String {
        canonical(url.appendingPathComponent(relativePath))
    }

    @discardableResult
    func file(
        _ relativePath: String,
        contents: Data,
        modified: Date? = nil,
        created: Date? = nil
    ) throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL)
        try setDates(at: fileURL, modified: modified, created: created)

        return fileURL
    }

    @discardableResult
    func text(
        _ relativePath: String,
        _ contents: String,
        modified: Date? = nil,
        created: Date? = nil
    ) throws -> URL {
        try file(relativePath, contents: Data(contents.utf8), modified: modified, created: created)
    }

    @discardableResult
    func folder(_ relativePath: String) throws -> URL {
        let folderURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        return folderURL
    }

    func symlink(_ relativePath: String, to destination: URL) throws {
        try FileManager.default.createSymbolicLink(
            at: url.appendingPathComponent(relativePath),
            withDestinationURL: destination
        )
    }

    func setPermissions(_ permissions: Int, at relativePath: String) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.appendingPathComponent(relativePath).path
        )
    }

    private func setDates(at fileURL: URL, modified: Date?, created: Date?) throws {
        var attributes: [FileAttributeKey: Any] = [:]

        if let modified {
            attributes[.modificationDate] = modified
        }

        if let created {
            attributes[.creationDate] = created
        }

        if !attributes.isEmpty {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
        }
    }
}

func digest(of data: Data, using algorithm: ChecksumAlgorithm) -> String {
    switch algorithm {
    case .sha256:
        return hex(SHA256.hash(data: data))
    case .sha1:
        return hex(Insecure.SHA1.hash(data: data))
    case .md5:
        return hex(Insecure.MD5.hash(data: data))
    }
}

private func hex<D: Digest>(_ digest: D) -> String {
    digest.map { String(format: "%02x", $0) }.joined()
}
