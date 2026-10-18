import Foundation

public enum ComparisonFileCodec {
    private static let metadataSection = "metadata"

    public static func parse(_ text: String, source: String = "") throws -> ChecksumComparison {
        let table: TableData

        do {
            table = try Csv.parse(
                text,
                options: CsvOptions(dataFormat: .excel, allowLineComments: true, hasHeader: false)
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

    public static func parse(contentsOf url: URL) throws -> ChecksumComparison {
        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CsumError.sourceUnreadable(path: url.path)
        }

        return try parse(String(decoding: data, as: UTF8.self), source: url.path)
    }

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

    private static func decode(_ table: TableData) throws -> ChecksumComparison {
        let values = MetadataComments.values(from: MetadataComments.all(from: table))
        let metadata = try metadata(from: values)

        var section: ComparisonSection?
        var rows: [ComparisonSection: [[String]]] = [:]

        for (index, row) in table.rows.enumerated() {
            guard let title = sectionTitle(in: table.commentsBeforeRow[index] ?? []) else {
                guard let section else {
                    throw MalformedFile(reason: .rowOutsideSections(row: index))
                }

                rows[section, default: []].append(row)

                continue
            }

            try validate(row, as: columns(for: title), section: title)
            section = title
        }

        return ChecksumComparison(
            metadata: metadata,
            unchanged: try entries(in: .unchanged, rows: rows),
            added: try entries(in: .added, rows: rows),
            removed: try entries(in: .removed, rows: rows),
            changed: try pairs(in: .changed, rows: rows),
            moved: try pairs(in: .moved, rows: rows),
            renamed: try pairs(in: .renamed, rows: rows)
        )
    }

    private static func validate(_ row: [String], as expected: [String], section: ComparisonSection) throws {
        guard row == expected else {
            throw MalformedFile(
                reason: .unexpectedColumns(
                    section: section.rawValue,
                    expected: expected.count,
                    found: row.count
                )
            )
        }
    }

    private static func sectionTitle(in comments: [String]) -> ComparisonSection? {
        for comment in comments {
            guard comment.hasPrefix("#") else {
                continue
            }

            let name = comment.dropFirst().trimmingCharacters(in: .whitespaces)

            if let section = ComparisonSection(rawValue: name.lowercased()) {
                return section
            }
        }

        return nil
    }

    private static func entries(
        in section: ComparisonSection,
        rows: [ComparisonSection: [[String]]]
    ) throws -> [ChecksumEntry] {
        try (rows[section] ?? []).enumerated().map { index, row in
            try EntryRowCodec.entry(from: row, section: section.rawValue, rowIndex: index)
        }
    }

    private static func pairs(
        in section: ComparisonSection,
        rows: [ComparisonSection: [[String]]]
    ) throws -> [MatchedEntry] {
        try (rows[section] ?? []).enumerated().map { index, row in
            try pair(from: row, section: section, rowIndex: index)
        }
    }

    private static func pair(
        from row: [String],
        section: ComparisonSection,
        rowIndex: Int
    ) throws -> MatchedEntry {
        let count = EntryColumns.all.count

        guard row.count == 2 * count else {
            throw MalformedFile(
                reason: .wrongFieldCount(
                    section: section.rawValue,
                    row: rowIndex,
                    expected: 2 * count,
                    found: row.count
                )
            )
        }

        return MatchedEntry(
            old: try EntryRowCodec.entry(from: Array(row[0 ..< count]), section: section.rawValue, rowIndex: rowIndex),
            new: try EntryRowCodec.entry(from: Array(row[count...]), section: section.rawValue, rowIndex: rowIndex)
        )
    }

    private static func metadata(from values: [String: String]) throws -> ComparisonMetadata {
        let version = try value("csum-format", in: values)
        let writer = try MetadataComments.tool(from: try value("csum-writer", in: values))
        let computed = try value("csum-computed", in: values)
        let algorithmText = try value("csum-algorithm", in: values)

        guard version == CsumFormat.version else {
            throw CsumError.unsupportedFormatVersion(found: version, expected: CsumFormat.version)
        }

        guard let algorithm = ChecksumAlgorithm(rawValue: algorithmText) else {
            throw MalformedFile(reason: .unparsableAlgorithm)
        }

        guard let computedAt = MetadataComments.date(from: computed) else {
            throw MalformedFile(reason: .unparsableTimestamp(section: metadataSection, row: 0))
        }

        return ComparisonMetadata(
            formatVersion: version,
            writer: writer.name,
            toolVersion: writer.version,
            computedAt: computedAt,
            algorithm: algorithm,
            first: try source("first", in: values),
            second: try source("second", in: values)
        )
    }

    private static func source(_ label: String, in values: [String: String]) throws -> ComparisonSource {
        let path = try value("csum-\(label)-path", in: values)
        let kindText = try value("csum-\(label)-kind", in: values)
        let root = try value("csum-\(label)-root", in: values)
        let computed = try value("csum-\(label)-computed", in: values)

        guard let kind = SourceKind(rawValue: kindText) else {
            throw MalformedFile(reason: .unparsableSourceKind(source: label))
        }

        guard let computedAt = MetadataComments.date(from: computed) else {
            throw MalformedFile(reason: .unparsableTimestamp(section: metadataSection, row: 0))
        }

        return ComparisonSource(path: path, kind: kind, root: root, computedAt: computedAt)
    }

    private static func value(_ key: String, in values: [String: String]) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw MalformedFile(reason: .missingMetadata)
        }

        return value
    }
}
