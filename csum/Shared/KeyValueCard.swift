import SwiftUI

struct KeyValueCard: View {
    let rows: [(label: LocalizedStringKey, value: String, singleLine: Bool, monospaced: Bool)]

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    separator
                }

                GridRow {
                    Text(rows[index].label)
                        .foregroundStyle(.secondary)

                    Text(verbatim: rows[index].value)
                        .font(rows[index].monospaced ? .body.monospaced() : .body)
                        .lineLimit(rows[index].singleLine ? 1 : nil)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1 / displayScale)
            .padding(.vertical, 7)
            .gridCellColumns(2)
    }
}
