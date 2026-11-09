import CsumController
import SwiftUI

struct DiffRow {
    let symbol: String
    let tint: DiffTint?
    let name: AttributedString
    let size: String
    let created: String
    let checksum: AttributedString
    let date: String
    let label: LocalizedStringKey
    let csv: String
}

enum DiffRows {
    private enum Emphasis {
        case none
        case checksum
        case path
        case leaf
    }

    private enum Label {
        case added
        case removed
        case unchanged
        case changedOld
        case changedNew
        case movedFrom
        case movedTo
        case renamedFrom
        case renamedTo
    }

    private enum Single {
        case added
        case removed
        case unchanged

        func fields(
            of comparison: ChecksumComparison
        ) -> (source: ComparisonSource, symbol: String, tint: DiffTint?, label: Label) {
            switch self {
            case .added:
                return (comparison.metadata.second, "+", .added, .added)

            case .removed:
                return (comparison.metadata.first, "−", .removed, .removed)

            case .unchanged:
                return (comparison.metadata.first, " ", nil, .unchanged)
            }
        }
    }

    private enum Paired {
        case changed
        case moved
        case renamed

        var emphasis: Emphasis {
            switch self {
            case .changed:
                return .checksum

            case .moved:
                return .path

            case .renamed:
                return .leaf
            }
        }

        func label(isNew: Bool) -> Label {
            switch self {
            case .changed:
                return isNew ? .changedNew : .changedOld

            case .moved:
                return isNew ? .movedTo : .movedFrom

            case .renamed:
                return isNew ? .renamedTo : .renamedFrom
            }
        }
    }

    private enum Rows {
        case single([ChecksumEntry], Single)
        case paired([MatchedEntry], Paired)
    }

    static func rowCount(
        for section: ComparisonSection,
        of comparison: ChecksumComparison
    ) -> Int {
        let entries = section.count(in: comparison)

        switch section {
        case .changed, .moved, .renamed:
            return entries * 2

        case .added, .removed, .unchanged:
            return entries
        }
    }

    static func row(
        at index: Int,
        in section: ComparisonSection,
        of comparison: ChecksumComparison
    ) -> DiffRow {
        switch rows(for: section, of: comparison) {
        case .single(let entries, let style):
            return entryRow(entries[index], as: style, of: comparison)

        case .paired(let pairs, let style):
            return pairRow(pairs[index / 2], as: style, of: comparison, isNew: index % 2 == 1)
        }
    }

    private static func rows(
        for section: ComparisonSection,
        of comparison: ChecksumComparison
    ) -> Rows {
        switch section {
        case .added:
            return .single(comparison.added, .added)

        case .removed:
            return .single(comparison.removed, .removed)

        case .unchanged:
            return .single(comparison.unchanged, .unchanged)

        case .changed:
            return .paired(comparison.changed, .changed)

        case .moved:
            return .paired(comparison.moved, .moved)

        case .renamed:
            return .paired(comparison.renamed, .renamed)
        }
    }

    private static func entryRow(
        _ entry: ChecksumEntry,
        as style: Single,
        of comparison: ChecksumComparison
    ) -> DiffRow {
        let fields = style.fields(of: comparison)

        return row(
            entry,
            source: fields.source,
            symbol: fields.symbol,
            tint: fields.tint,
            label: fields.label
        )
    }

    private static func pairRow(
        _ matched: MatchedEntry,
        as style: Paired,
        of comparison: ChecksumComparison,
        isNew: Bool
    ) -> DiffRow {
        let entry = isNew ? matched.new : matched.old
        let source = isNew ? comparison.metadata.second : comparison.metadata.first
        let symbol = isNew ? "+" : "−"
        let tint: DiffTint? = isNew ? .added : .removed

        return row(
            entry,
            source: source,
            symbol: symbol,
            tint: tint,
            label: style.label(isNew: isNew),
            emphasis: style.emphasis
        )
    }

    private static func row(
        _ entry: ChecksumEntry,
        source: ComparisonSource,
        symbol: String,
        tint: DiffTint?,
        label: Label,
        emphasis: Emphasis = .none
    ) -> DiffRow {
        let path = source.relativePath(of: entry)
        let highlight = tint?.emphasis

        var name = AttributedString(path)

        switch emphasis {
        case .path:
            name.backgroundColor = highlight
        case .leaf:
            if let leaf = path.split(separator: "/").last, let range = name.range(of: String(leaf))
            {
                name[range].backgroundColor = highlight
            }
        case .none, .checksum:
            break
        }

        var checksum = AttributedString(Format.checksum(entry))

        if case .checksum = emphasis {
            checksum.backgroundColor = highlight
        }

        let isolatedPath = Format.isolated(path)
        let isolatedChecksum = Format.isolated(Format.checksum(entry))

        let accessibilityLabel: LocalizedStringKey

        switch label {
        case .added:
            accessibilityLabel = "Added, \(isolatedPath)"
        case .removed:
            accessibilityLabel = "Removed, \(isolatedPath)"
        case .unchanged:
            accessibilityLabel = "Unchanged, \(isolatedPath)"
        case .changedOld:
            accessibilityLabel = "Changed, \(isolatedPath), old checksum \(isolatedChecksum)"
        case .changedNew:
            accessibilityLabel = "Changed, \(isolatedPath), new checksum \(isolatedChecksum)"
        case .movedFrom:
            accessibilityLabel = "Moved from \(isolatedPath)"
        case .movedTo:
            accessibilityLabel = "Moved to \(isolatedPath)"
        case .renamedFrom:
            accessibilityLabel = "Renamed from \(isolatedPath)"
        case .renamedTo:
            accessibilityLabel = "Renamed to \(isolatedPath)"
        }

        return DiffRow(
            symbol: symbol,
            tint: tint,
            name: name,
            size: Format.size(entry.size),
            created: Format.day(entry.created),
            checksum: checksum,
            date: Format.day(entry.modified),
            label: accessibilityLabel,
            csv: ChecksumRowText.line(for: entry)
        )
    }
}

struct DiffRowView: View {
    let row: DiffRow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: row.symbol)
                .fontWeight(.semibold)
                .frame(width: 14, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.name)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    Text(verbatim: row.size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.checksum)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(verbatim: row.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .copyRowMenu(row.csv)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
    }
}
