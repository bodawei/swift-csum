import CsumController
import SwiftUI

struct DiffRow: Identifiable {
    let id: String
    let symbol: String
    let tint: DiffTint?
    let name: AttributedString
    let size: String
    let created: String
    let checksum: AttributedString
    let date: String
    let label: LocalizedStringKey
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

    static func rows(for section: ComparisonSection, of comparison: ChecksumComparison) -> [DiffRow]
    {
        switch section {
        case .added:
            comparison.added.map {
                row(
                    $0,
                    source: comparison.metadata.second,
                    symbol: "+",
                    tint: .added,
                    emphasis: .none,
                    label: .added,
                    id: "added-\($0.path)"
                )
            }
        case .removed:
            comparison.removed.map {
                row(
                    $0,
                    source: comparison.metadata.first,
                    symbol: "−",
                    tint: .removed,
                    emphasis: .none,
                    label: .removed,
                    id: "removed-\($0.path)"
                )
            }
        case .unchanged:
            comparison.unchanged.map {
                row(
                    $0,
                    source: comparison.metadata.first,
                    symbol: " ",
                    tint: nil,
                    emphasis: .none,
                    label: .unchanged,
                    id: "unchanged-\($0.path)"
                )
            }
        case .changed:
            comparison.changed.flatMap { pair($0, of: comparison, emphasis: .checksum) }
        case .moved:
            comparison.moved.flatMap { pair($0, of: comparison, emphasis: .path) }
        case .renamed:
            comparison.renamed.flatMap { pair($0, of: comparison, emphasis: .leaf) }
        }
    }

    private static func pair(
        _ matched: MatchedEntry,
        of comparison: ChecksumComparison,
        emphasis: Emphasis
    ) -> [DiffRow] {
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

        return [
            row(
                matched.old,
                source: comparison.metadata.first,
                symbol: "−",
                tint: .removed,
                emphasis: emphasis,
                label: labels.0,
                id: "old-\(matched.old.path)"
            ),
            row(
                matched.new,
                source: comparison.metadata.second,
                symbol: "+",
                tint: .added,
                emphasis: emphasis,
                label: labels.1,
                id: "new-\(matched.new.path)"
            ),
        ]
    }

    private static func row(
        _ entry: ChecksumEntry,
        source: ComparisonSource,
        symbol: String,
        tint: DiffTint?,
        emphasis: Emphasis,
        label: Label,
        id: String
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
            id: id,
            symbol: symbol,
            tint: tint,
            name: name,
            size: Format.size(entry.size),
            created: Format.day(entry.created),
            checksum: checksum,
            date: Format.day(entry.modified),
            label: accessibilityLabel
        )
    }
}

struct DiffRowView: View {
    let row: DiffRow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: row.symbol)
                .fontWeight(.semibold)
                .foregroundStyle(row.tint?.marker ?? Color.secondary)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
    }
}
