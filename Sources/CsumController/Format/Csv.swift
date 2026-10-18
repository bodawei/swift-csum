import Foundation

public enum DataFormat {
    case excel

    var lineEnding: String {
        switch self {
        case .excel:
            return "\r\n"
        }
    }

    var emitsBOM: Bool {
        switch self {
        case .excel:
            return true
        }
    }

    var quoting: Quoting {
        switch self {
        case .excel:
            return .doubleQuotes
        }
    }
}

public enum Quoting {
    case doubleQuotes
}

public struct CsvOptions {
    public var dataFormat: DataFormat
    public var allowLineComments: Bool
    public var hasHeader: Bool

    public init(dataFormat: DataFormat = .excel, allowLineComments: Bool = false, hasHeader: Bool = false) {
        self.dataFormat = dataFormat
        self.allowLineComments = allowLineComments
        self.hasHeader = hasHeader
    }
}

public enum CsvParseError: Error {
    case unterminatedQuote
}

public struct TableData {
    public var columns: [String]
    public var leadingComments: [String]
    public var rows: [[String]]
    public var commentsBeforeRow: [Int: [String]]

    public init(
        columns: [String] = [],
        leadingComments: [String] = [],
        rows: [[String]] = [],
        commentsBeforeRow: [Int: [String]] = [:]
    ) {
        self.columns = columns
        self.leadingComments = leadingComments
        self.rows = rows
        self.commentsBeforeRow = commentsBeforeRow
    }

    public func getField(_ column: String, row: Int) -> String? {
        guard rows.indices.contains(row), let index = columns.firstIndex(of: column) else {
            return nil
        }

        guard index < rows[row].count else {
            return nil
        }

        return rows[row][index]
    }

    public func getField(column index: Int, row: Int) -> String? {
        guard rows.indices.contains(row), columns.indices.contains(index) else {
            return nil
        }

        guard index < rows[row].count else {
            return nil
        }

        return rows[row][index]
    }
}

public enum Csv {
    public static func parse(_ text: String, options: CsvOptions) throws -> TableData {
        let fields = try parseFields(text)
        var columns: [String] = []
        var leadingComments: [String] = []
        var rows: [[String]] = []
        var commentsBeforeRow: [Int: [String]] = [:]
        var pendingComments: [String] = []
        var didReadHeader = false

        for line in fields {
            let isBlank = line.isEmpty || (line.count == 1 && line[0].isEmpty)

            if isBlank {
                continue
            }

            if options.allowLineComments, line[0].hasPrefix("#") {
                pendingComments.append(line.joined(separator: ","))

                continue
            }

            if options.hasHeader, !didReadHeader {
                columns = line
                leadingComments = pendingComments
                pendingComments = []
                didReadHeader = true

                continue
            }

            if !pendingComments.isEmpty {
                commentsBeforeRow[rows.count] = pendingComments
                pendingComments = []
            }

            rows.append(line)
        }

        if !pendingComments.isEmpty {
            commentsBeforeRow[rows.count] = pendingComments
        }

        return TableData(
            columns: columns,
            leadingComments: leadingComments,
            rows: rows,
            commentsBeforeRow: commentsBeforeRow
        )
    }

    public static func stringify(_ data: TableData, options: CsvOptions) -> String {
        var lines: [String] = []

        if options.allowLineComments {
            lines.append(contentsOf: data.leadingComments.map(formatField))
        }

        if options.hasHeader {
            lines.append(stringifyLine(data.columns, quoting: options.dataFormat.quoting))
        }

        for index in data.rows.indices {
            if options.allowLineComments, let block = data.commentsBeforeRow[index] {
                lines.append(contentsOf: block.map(formatField))
            }

            lines.append(stringifyLine(data.rows[index], quoting: options.dataFormat.quoting))
        }

        if options.allowLineComments, let block = data.commentsBeforeRow[data.rows.count] {
            lines.append(contentsOf: block.map(formatField))
        }

        let body = lines.joined(separator: options.dataFormat.lineEnding)

        if options.dataFormat.emitsBOM {
            return "\u{FEFF}" + body
        }

        return body
    }

    private static func stringifyLine(_ values: [String], quoting: Quoting) -> String {
        switch quoting {
        case .doubleQuotes:
            return values.map(formatField).joined(separator: ",")
        }
    }

    static func formatField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") || value.hasPrefix(" ") || value.hasSuffix(" ") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        return value
    }

    private static func parseFields(_ text: String) throws -> [[String]] {
        var scalars = text.unicodeScalars

        if scalars.first == "\u{FEFF}" {
            scalars.removeFirst()
        }

        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    let next = scalars.index(after: index)

                    if next < scalars.endIndex && scalars[next] == "\"" {
                        field.append(scalar)
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else if scalar == "\"" {
                inQuotes = true
            } else if scalar == "," {
                row.append(String(field))
                field = String.UnicodeScalarView()
            } else if scalar == "\n" || scalar == "\r" {
                row.append(String(field))
                field = String.UnicodeScalarView()
                rows.append(row)
                row = []

                if scalar == "\r" {
                    let next = scalars.index(after: index)

                    if next < scalars.endIndex && scalars[next] == "\n" {
                        index = next
                    }
                }
            } else {
                field.append(scalar)
            }

            index = scalars.index(after: index)
        }

        if inQuotes {
            throw CsvParseError.unterminatedQuote
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }

        return rows
    }
}
