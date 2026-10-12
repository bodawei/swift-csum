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

extension TableData {
    public init(checksumRows rows: [CsumCsvDataRow]) {
        self.init(columns: ChecksumColumns.all, rows: rows.map { $0.fields })
    }

    public var checksumRows: [CsumCsvDataRow] {
        rows.map(CsumCsvDataRow.init(fields:))
    }
}
