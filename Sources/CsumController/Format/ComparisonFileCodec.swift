import Foundation

public enum ComparisonFileCodec {
    public static func render(
        _ comparison: ChecksumComparison,
        sections: [ComparisonSection] = ComparisonSection.allCases
    ) -> String {
        var table = TableData()
        table.leadingComments = comments(for: comparison.metadata)

        let rows = rows(of: comparison)

        for section in ComparisonSection.allCases where sections.contains(section) {
            guard let sectionRows = rows[section], !sectionRows.isEmpty else {
                continue
            }

            table.commentsBeforeRow[table.rows.count] = ["# \(title(for: section))"]
            table.rows.append(columns(for: section))
            table.rows.append(contentsOf: sectionRows)
        }

        let text = Csv.stringify(
            table,
            options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: false)
        )

        return text + DataFormat.excel.lineEnding
    }

    private static func comments(for metadata: ComparisonMetadata) -> [String] {
        [
            MetadataComments.line(key: "csum-format", value: metadata.formatVersion),
            MetadataComments.line(key: "csum-writer", value: "\(metadata.writer) \(metadata.toolVersion)"),
            MetadataComments.line(key: "csum-computed", value: MetadataComments.timestampText(for: metadata.computedAt)),
            MetadataComments.line(key: "csum-algorithm", value: metadata.algorithm.rawValue)
        ] + comments(for: metadata.first, label: "first") + comments(for: metadata.second, label: "second")
    }

    private static func comments(for source: ComparisonSource, label: String) -> [String] {
        [
            MetadataComments.line(key: "csum-\(label)-path", value: source.path),
            MetadataComments.line(key: "csum-\(label)-kind", value: source.kind.rawValue),
            MetadataComments.line(key: "csum-\(label)-root", value: source.root),
            MetadataComments.line(
                key: "csum-\(label)-computed",
                value: MetadataComments.timestampText(for: source.computedAt)
            )
        ]
    }

    private static func rows(of comparison: ChecksumComparison) -> [ComparisonSection: [[String]]] {
        [
            .added: comparison.added.map(EntryRowCodec.row(for:)),
            .removed: comparison.removed.map(EntryRowCodec.row(for:)),
            .changed: comparison.changed.map(row(for:)),
            .moved: comparison.moved.map(row(for:)),
            .renamed: comparison.renamed.map(row(for:)),
            .unchanged: comparison.unchanged.map(EntryRowCodec.row(for:))
        ]
    }

    private static func row(for pair: MatchedEntry) -> [String] {
        EntryRowCodec.row(for: pair.old) + EntryRowCodec.row(for: pair.new)
    }

    private static func title(for section: ComparisonSection) -> String {
        section.rawValue.prefix(1).uppercased() + section.rawValue.dropFirst()
    }

    private static func columns(for section: ComparisonSection) -> [String] {
        switch section {
        case .added, .removed, .unchanged:
            return EntryColumns.all
        case .changed, .moved, .renamed:
            return entryColumns(prefix: "Old") + entryColumns(prefix: "New")
        }
    }

    private static func entryColumns(prefix: String) -> [String] {
        EntryColumns.all.map { "\(prefix) \($0)" }
    }
}
