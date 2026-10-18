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
}
