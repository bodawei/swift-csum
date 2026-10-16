import Foundation

public enum ChecksumFileCodec {
    private static let section = "checksum"
    private static let metadataSection = "metadata"

    public static func parse(_ text: String, source: String = "") throws -> ChecksumResult {
        let table: TableData

        do {
            table = try Csv.parse(
                text,
                options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: true)
            )
        } catch {
            throw CsumError.malformedFile(path: source, reason: .unterminatedQuote)
        }

        do {
            return try decode(table)
        } catch let malformed as MalformedFile {
            throw CsumError.malformedFile(path: source, reason: malformed.reason)
        }
    }

    public static func parse(contentsOf url: URL) throws -> ChecksumResult {
        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CsumError.sourceUnreadable(path: url.path)
        }

        return try parse(String(decoding: data, as: UTF8.self), source: url.path)
    }

    public static func render(_ result: ChecksumResult) -> String {
        var table = TableData(columns: EntryColumns.all)
        table.leadingComments = comments(for: result.metadata)
        table.rows = result.entries.map(EntryRowCodec.row(for:))

        let text = Csv.stringify(
            table,
            options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: true)
        )

        return text + DataFormat.excel.lineEnding
    }

    private static func comments(for metadata: ChecksumMetadata) -> [String] {
        [
            MetadataComments.line(key: "csum-format", value: metadata.formatVersion),
            MetadataComments.line(key: "csum-writer", value: "\(metadata.writer) \(metadata.toolVersion)"),
            MetadataComments.line(key: "csum-computed", value: timestampText(for: metadata.computedAt)),
            MetadataComments.line(key: "csum-algorithm", value: metadata.algorithm.rawValue),
            MetadataComments.line(key: "csum-root", value: metadata.root)
        ]
    }

    private static func decode(_ table: TableData) throws -> ChecksumResult {
        let metadata = try metadata(from: MetadataComments.values(from: table.leadingComments))

        guard table.columns == EntryColumns.all else {
            throw MalformedFile(
                reason: .unexpectedColumns(
                    section: section,
                    expected: EntryColumns.all.count,
                    found: table.columns.count
                )
            )
        }

        let entries = try table.rows.enumerated().map { index, row in
            try EntryRowCodec.entry(from: row, section: section, rowIndex: index)
        }

        return ChecksumResult(metadata: metadata, entries: entries)
    }

    private static func metadata(from values: [String: String]) throws -> ChecksumMetadata {
        guard let version = values["csum-format"] else {
            throw MalformedFile(reason: .missingMetadata)
        }

        guard let writer = values["csum-writer"] else {
            throw MalformedFile(reason: .missingMetadata)
        }

        guard let computed = values["csum-computed"] else {
            throw MalformedFile(reason: .missingMetadata)
        }

        guard let algorithmText = values["csum-algorithm"] else {
            throw MalformedFile(reason: .missingMetadata)
        }

        guard let root = values["csum-root"], !root.isEmpty else {
            throw MalformedFile(reason: .missingMetadata)
        }

        guard version == CsumFormat.version else {
            throw CsumError.unsupportedFormatVersion(found: version, expected: CsumFormat.version)
        }

        guard let algorithm = ChecksumAlgorithm(rawValue: algorithmText) else {
            throw MalformedFile(reason: .unparsableAlgorithm)
        }

        guard let computedAt = date(from: computed) else {
            throw MalformedFile(reason: .unparsableTimestamp(section: metadataSection, row: 0))
        }

        let parts = try MetadataComments.tool(from: writer)

        return ChecksumMetadata(
            formatVersion: version,
            writer: parts.name,
            toolVersion: parts.version,
            algorithm: algorithm,
            computedAt: computedAt,
            root: root
        )
    }

    private static func timestampText(for date: Date) -> String {
        MetadataComments.timestampText(for: date)
    }

    private static func date(from text: String) -> Date? {
        MetadataComments.date(from: text)
    }
}
