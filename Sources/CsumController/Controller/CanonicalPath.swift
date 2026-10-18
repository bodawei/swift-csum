import Foundation

enum CanonicalPath {
    static func of(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else {
            return path
        }

        defer {
            free(resolved)
        }

        return String(cString: resolved)
    }

    static func relativePath(of path: String, root: String) -> String {
        if path == root {
            return ""
        }

        let prefix = root.hasSuffix("/") ? root : root + "/"

        guard path.hasPrefix(prefix) else {
            return path
        }

        return String(path.dropFirst(prefix.count))
    }
}
