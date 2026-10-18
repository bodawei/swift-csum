import Foundation

enum MetadataComments {
    static func line(key: String, value: String) -> String {
        "# \(key) \(value)"
    }

    static func tool(from text: String) throws -> (name: String, version: String) {
        let parts = text.split(separator: " ")

        guard parts.count >= 2 else {
            throw MalformedFile(reason: .missingMetadata)
        }

        return (parts.dropLast().joined(separator: " "), String(parts[parts.count - 1]))
    }

    static func timestampText(for date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func date(from text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }

    static func all(from table: TableData) -> [String] {
        var comments = table.leadingComments

        for index in table.commentsBeforeRow.keys.sorted() {
            comments.append(contentsOf: table.commentsBeforeRow[index] ?? [])
        }

        return comments
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
