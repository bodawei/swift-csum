import CsumController
import SwiftUI

struct DiffRow: Identifiable {
    let id: String
    let symbol: String
    let tint: Color?
    let name: AttributedString
    let size: String
    let created: String
    let checksum: AttributedString
    let date: String
}

enum DiffRows {
    private enum Emphasis {
        case none
        case checksum
        case path
        case leaf
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
                    tint: .green,
                    emphasis: .none,
                    id: "added-\($0.path)"
                )
            }
        case .removed:
            comparison.removed.map {
                row(
                    $0,
                    source: comparison.metadata.first,
                    symbol: "−",
                    tint: .red,
                    emphasis: .none,
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
        [
            row(
                matched.old,
                source: comparison.metadata.first,
                symbol: "−",
                tint: .red,
                emphasis: emphasis,
                id: "old-\(matched.old.path)"
            ),
            row(
                matched.new,
                source: comparison.metadata.second,
                symbol: "+",
                tint: .green,
                emphasis: emphasis,
                id: "new-\(matched.new.path)"
            ),
        ]
    }

    private static func row(
        _ entry: ChecksumEntry,
        source: ComparisonSource,
        symbol: String,
        tint: Color?,
        emphasis: Emphasis,
        id: String
    ) -> DiffRow {
        let path = source.relativePath(of: entry)
        let highlight = tint ?? .accentColor

        var name = AttributedString(path)

        switch emphasis {
        case .path:
            name.backgroundColor = highlight.opacity(0.22)
        case .leaf:
            if let leaf = path.split(separator: "/").last, let range = name.range(of: String(leaf))
            {
                name[range].backgroundColor = highlight.opacity(0.22)
            }
        default:
            break
        }

        var checksum = AttributedString(Format.checksum(entry))

        if case .checksum = emphasis {
            checksum.backgroundColor = highlight.opacity(0.22)
        }

        return DiffRow(
            id: id,
            symbol: symbol,
            tint: tint,
            name: name,
            size: Format.size(entry.size),
            created: Format.day(entry.created),
            checksum: checksum,
            date: Format.day(entry.modified)
        )
    }
}

struct DiffRowView: View {
    let row: DiffRow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: row.symbol)
                .fontWeight(.semibold)
                .foregroundStyle(row.tint ?? Color.secondary)
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
        .accessibilityElement(children: .combine)
    }
}
