import Foundation

enum MetadataComments {
    static func line(key: String, value: String) -> String {
        "# \(key) \(value)"
    }

    static func keyValue(from comment: String) -> (key: String, value: String)? {
        guard comment.hasPrefix("#") else {
            return nil
        }

        let body = String(comment.dropFirst()).trimmingCharacters(in: .whitespaces)

        guard body.hasPrefix("csum-") else {
            return nil
        }

        guard let spaceIndex = body.firstIndex(of: " ") else {
            return (body, "")
        }

        let key = String(body[..<spaceIndex])
        let value = String(body[body.index(after: spaceIndex)...])

        return (key, value)
    }

    static func values(from comments: [String]) -> [String: String] {
        var values: [String: String] = [:]

        for comment in comments {
            guard let pair = keyValue(from: comment) else {
                continue
            }

            values[pair.key] = pair.value
        }

        return values
    }
}
