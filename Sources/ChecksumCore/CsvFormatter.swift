import Foundation

public enum CsvFormattingUtils {
    public static func generateTsvText(rows: [CsumCsvDataRow]) -> String {
        Tsv.stringify(TableData(rows: rows.map { $0.fields }))
    }

    public static func formatSection(title: String, rows: [CsumCsvDataRow]) -> String {
        var table = TableData(checksumRows: rows)
        table.leadingComments = ["# \(title)"]

        let text = Csv.stringify(
            table,
            options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: true)
        )

        return text + DataFormat.excel.lineEnding
    }

    public static func formatPairSection(title: String, pairs: [MovedPair]) -> String {
        let pairHeader = "Filename,Checksum,Size,From,To"
        let body = pairs.map { pair in
            formatLine([pair.to.filename, pair.to.checksum, pair.to.size, pair.from.path, pair.to.path])
        }.joined(separator: "\r\n")

        return "# \(title)\r\n\(pairHeader)\r\n\(body)\r\n"
    }

    public static func buildFileText(
        rows: [CsumCsvDataRow],
        sourcePaths: String,
        writer: String,
        version: String,
        date: Date = Date()
    ) -> String {
        let stamp = ISO8601DateFormatter().string(from: date)
        var table = TableData(checksumRows: rows)
        table.leadingComments = [
            "# written by \(writer) v\(version).",
            "# Checksums of files at \(sourcePaths) done on \(stamp)"
        ]

        let text = Csv.stringify(
            table,
            options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: true)
        )

        return text + DataFormat.excel.lineEnding
    }
}
