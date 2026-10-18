import SwiftUI

struct KeyValueCard: View {
    let rows: [(label: LocalizedStringKey, value: String, singleLine: Bool, monospaced: Bool)]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
            ForEach(rows.indices, id: \.self) { index in
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
}
