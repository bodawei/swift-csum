import Foundation

public enum ChecksumColumns {
    public static let filename = "Filename"
    public static let checksum = "Checksum"
    public static let algorithm = "Algorithm"
    public static let size = "Size"
    public static let created = "Created"
    public static let modified = "Modified"
    public static let path = "Path"

    public static let all = [filename, checksum, algorithm, size, created, modified, path]
}

public struct CsumCsvDataRow: Sendable {
    public var filename = ""
    public var checksum = ""
    public var algorithm = ""
    public var size = ""
    public var created = ""
    public var modified = ""
    public var path = ""

    public init(
        filename: String = "",
        checksum: String = "",
        algorithm: String = "",
        size: String = "",
        created: String = "",
        modified: String = "",
        path: String = ""
    ) {
        self.filename = filename
        self.checksum = checksum
        self.algorithm = algorithm
        self.size = size
        self.created = created
        self.modified = modified
        self.path = path
    }

    public init(fields: [String]) {
        if fields.count > 0 { filename = fields[0] }

        if fields.count > 1 { checksum = fields[1] }

        if fields.count > 2 { algorithm = fields[2] }

        if fields.count > 3 { size = fields[3] }

        if fields.count > 4 { created = fields[4] }

        if fields.count > 5 { modified = fields[5] }

        if fields.count > 6 { path = fields[6] }
    }

    public var fields: [String] {
        [filename, checksum, algorithm, size, created, modified, path]
    }
}

public struct ChecksumTable: Sendable {
    public var columns = ChecksumColumns.all
    public var leadingComments: [String] = []
    public var commentsBeforeRow: [Int: [String]] = [:]
    public var rows: [CsumCsvDataRow] = []

    public init(
        rows: [CsumCsvDataRow] = [],
        leadingComments: [String] = [],
        commentsBeforeRow: [Int: [String]] = [:]
    ) {
        self.rows = rows
        self.leadingComments = leadingComments
        self.commentsBeforeRow = commentsBeforeRow
    }

    public init(table: TableData) {
        self.init(
            rows: table.rows.map { CsumCsvDataRow(fields: $0) },
            leadingComments: table.leadingComments,
            commentsBeforeRow: table.commentsBeforeRow
        )
    }

    public var table: TableData {
        TableData(
            columns: columns,
            leadingComments: leadingComments,
            rows: rows.map(\.fields),
            commentsBeforeRow: commentsBeforeRow
        )
    }
}
