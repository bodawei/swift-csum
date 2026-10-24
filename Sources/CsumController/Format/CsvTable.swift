import Foundation

public struct CsvTable: Sendable {
    public struct Row: Identifiable, Sendable {
        public let id: Int
        public let fields: [String]
        public let isComment: Bool

        public init(id: Int, fields: [String], isComment: Bool) {
            self.id = id
            self.fields = fields
            self.isComment = isComment
        }

        public var text: String {
            fields.joined(separator: ",")
        }
    }

    public let rows: [Row]
    public let text: String

    public init(rows: [Row], text: String) {
        self.rows = rows
        self.text = text
    }

    public var columnCount: Int {
        rows.map { $0.fields.count }.max() ?? 0
    }

    public init(parsing text: String, source: String = "") throws {
        let table: TableData

        do {
            table = try Csv.parse(
                text,
                options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: false)
            )
        } catch {
            throw CsumError.malformedFile(path: source, reason: .unterminatedQuote)
        }

        var rows: [Row] = []

        func appendComment(_ comment: String) {
            rows.append(Row(id: rows.count, fields: [comment], isComment: true))
        }

        table.leadingComments.forEach(appendComment)

        for index in table.rows.indices {
            (table.commentsBeforeRow[index] ?? []).forEach(appendComment)
            rows.append(Row(id: rows.count, fields: table.rows[index], isComment: false))
        }

        (table.commentsBeforeRow[table.rows.count] ?? []).forEach(appendComment)

        self.init(rows: rows, text: text)
    }

    public init(contentsOf url: URL) throws {
        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CsumError.sourceUnreadable(path: url.path)
        }

        try self.init(parsing: String(decoding: data, as: UTF8.self), source: url.path)
    }
}
