import SwiftUI

enum TableColumns {
    static let size: CGFloat = 80
    static let date: CGFloat = 104
    static let spacing: CGFloat = 12
    static let nameShare: CGFloat = 0.58
}

enum TableStriping {
    static func color(forRow index: Int) -> Color? {
        index.isMultiple(of: 2) ? nil : Color.primary.opacity(0.045)
    }
}

private struct TableColumnsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0

        for (subview, column) in zip(subviews, columns(for: width)) {
            let size = subview.sizeThatFits(
                ProposedViewSize(width: column, height: proposal.height))
            height = max(height, size.height)
        }

        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX

        for (subview, column) in zip(subviews, columns(for: bounds.width)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: column, height: bounds.height)
            )

            x += column + TableColumns.spacing
        }
    }

    private func columns(for width: CGFloat) -> [CGFloat] {
        let fixed =
            TableColumns.size + TableColumns.date * 2 + TableColumns.spacing * 4
        let flexible = max(0, width - fixed)
        let name = flexible * TableColumns.nameShare

        return [
            name, TableColumns.size, TableColumns.date, TableColumns.date,
            flexible - name,
        ]
    }
}

struct TableHeader: View {
    var body: some View {
        TableColumnsLayout {
            Text("Name")

            Text("Size")
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("Created")

            Text("Modified")

            Text("Checksum")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .textCase(nil)
    }
}

struct TableRowLayout<Name: View, Checksum: View>: View {
    private let size: String
    private let created: String
    private let modified: String
    private let name: Name
    private let checksum: Checksum

    init(
        size: String,
        created: String,
        modified: String,
        @ViewBuilder name: () -> Name,
        @ViewBuilder checksum: () -> Checksum
    ) {
        self.size = size
        self.created = created
        self.modified = modified
        self.name = name()
        self.checksum = checksum()
    }

    var body: some View {
        TableColumnsLayout {
            name

            Text(verbatim: size)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(verbatim: created)

            Text(verbatim: modified)

            checksum
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .lineLimit(1)
        .padding(.vertical, 5)
    }
}
