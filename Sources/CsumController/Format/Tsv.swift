import Foundation

public enum Tsv {
    public static func stringify(_ data: TableData) -> String {
        var lines: [String] = []

        if !data.columns.isEmpty {
            lines.append(data.columns.joined(separator: "\t"))
        }

        lines.append(contentsOf: data.rows.map { $0.joined(separator: "\t") })

        return lines.joined(separator: "\n")
    }
}
