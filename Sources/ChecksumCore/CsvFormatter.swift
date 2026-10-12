import Foundation

public enum CsvFormatter {
    public static let header = "Filename,Checksum,Algorithm,Size,Created,Modified,Path"

    public static func rowValues(_ row: CsvRow) -> [String] {
        [row.filename, row.checksum, row.algorithm, row.size, row.created, row.modified, row.path]
    }

    public static func field(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        return value
    }

    public static func line(_ values: [String]) -> String {
        values.map(field).joined(separator: ",")
    }

    public static func tsvLine(_ values: [String]) -> String {
        values.joined(separator: "\t")
    }

    public static func section(title: String, rows: [CsvRow]) -> String {
        let body = rows.map { line(rowValues($0)) }.joined(separator: "\r\n")

        return "# \(title)\r\n\(header)\r\n\(body)\r\n"
    }

    public static func fileText(
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
        let body = rows.map { line(rowValues($0)) }.joined(separator: "\r\n")

        return (comments + [header, body]).joined(separator: "\r\n") + "\r\n"
    }
}
