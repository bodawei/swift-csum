import Foundation

public enum CsvFormattingUtils {
    private static let header = "Filename,Checksum,Algorithm,Size,Created,Modified,Path"

    public static func rowValues(_ row: CsvRow) -> [String] {
        [row.filename, row.checksum, row.algorithm, row.size, row.created, row.modified, row.path]
    }

    private static func formatField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        return value
    }

    private static func formatLine(_ values: [String]) -> String {
        values.map(formatField).joined(separator: ",")
    }

    public static func generateTsvText(rows: [CsvRow]) -> String {
        rows.map { rowValues($0).joined(separator: "\t") }.joined(separator: "\n")
    }

    public static func formatSection(title: String, rows: [CsvRow]) -> String {
        let body = rows.map { formatLine(rowValues($0)) }.joined(separator: "\r\n")

        return "# \(title)\r\n\(header)\r\n\(body)\r\n"
    }

    public static func buildFileText(
        rows: [CsvRow],
        sourcePaths: String,
        writer: String,
        version: String,
        date: Date = Date()
    ) -> String {
        let stamp = ISO8601DateFormatter().string(from: date)
        let comments = [
            "# written by \(writer) v\(version).",
            "# Checksums of files at \(sourcePaths) done on \(stamp)"
        ]
        let body = rows.map { formatLine(rowValues($0)) }.joined(separator: "\r\n")

        return (comments + [header, body]).joined(separator: "\r\n") + "\r\n"
    }
}
