import Foundation

public enum CsvFormattingUtils {
    public static func generateTsvText(rows: [CsumCsvDataRow]) -> String {
        Tsv.stringify(ChecksumTable(rows: rows).table)
    }

    public static func formatSection(title: String, rows: [CsumCsvDataRow]) -> String {
        var table = ChecksumTable(rows: rows)
        table.leadingComments = ["# \(title)"]

        return render(table.table)
    }

    public static func formatPairSection(title: String, pairs: [MovedPair]) -> String {
        var table = TableData(columns: ["Filename", "Checksum", "Size", "From", "To"])
        table.leadingComments = ["# \(title)"]
        table.rows = pairs.map { [$0.to.filename, $0.to.checksum, $0.to.size, $0.from.path, $0.to.path] }

        return render(table)
    }

    public static func buildFileText(
        rows: [CsumCsvDataRow],
        sourcePaths: String,
        writer: String,
        version: String,
        date: Date = Date()
    ) -> String {
        let stamp = ISO8601DateFormatter().string(from: date)
        var table = ChecksumTable(rows: rows)
        table.leadingComments = [
            "# written by \(writer) v\(version).",
            "# Checksums of files at \(sourcePaths) done on \(stamp)"
        ]

        return render(table.table)
    }

    private static func render(_ table: TableData) -> String {
        let text = Csv.stringify(
            table,
            options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: true)
        )

        return text + DataFormat.excel.lineEnding
    }
}
