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
        switch section {
        case .added:
            return row(
                comparison.added[index],
                source: comparison.metadata.second,
                symbol: "+",
                tint: .added,
                emphasis: .none,
                label: .added
            )

        case .removed:
            return row(
                comparison.removed[index],
                source: comparison.metadata.first,
                symbol: "−",
                tint: .removed,
                emphasis: .none,
                label: .removed
            )

        case .unchanged:
            return row(
                comparison.unchanged[index],
                source: comparison.metadata.first,
                symbol: " ",
                tint: nil,
                emphasis: .none,
                label: .unchanged
            )

        case .changed:
            return pairRow(
                comparison.changed[index / 2],
                of: comparison,
                emphasis: .checksum,
                isNew: index % 2 == 1
            )

        case .moved:
            return pairRow(
                comparison.moved[index / 2],
                of: comparison,
                emphasis: .path,
                isNew: index % 2 == 1
            )

        case .renamed:
            return pairRow(
                comparison.renamed[index / 2],
                of: comparison,
                emphasis: .leaf,
                isNew: index % 2 == 1
            )
        }
    }

    private static func pairRow(
        _ matched: MatchedEntry,
        of comparison: ChecksumComparison,
        emphasis: Emphasis,
        isNew: Bool
    ) -> DiffRow {
        let labels: (Label, Label)

        switch emphasis {
        case .checksum:
            labels = (.changedOld, .changedNew)
        case .path:
            labels = (.movedFrom, .movedTo)
        case .leaf:
            labels = (.renamedFrom, .renamedTo)
        case .none:
            labels = (.unchanged, .unchanged)
        }

        guard isNew else {
            return row(
                matched.old,
                source: comparison.metadata.first,
                symbol: "−",
                tint: .removed,
                emphasis: emphasis,
                label: labels.0
            )
        }

        return row(
            matched.new,
            source: comparison.metadata.second,
            symbol: "+",
            tint: .added,
            emphasis: emphasis,
            label: labels.1
        )
    }

    private static func row(
        _ entry: ChecksumEntry,
        source: ComparisonSource,
        symbol: String,
        tint: DiffTint?,
        emphasis: Emphasis,
        label: Label
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
        default:
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
