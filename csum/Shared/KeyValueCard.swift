import SwiftUI

struct KeyValueCard: View {
    struct Row {
        let label: LocalizedStringKey
        let value: String
        let singleLine: Bool
        let monospaced: Bool
    }

    let rows: [Row]

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    separator
                }

                row(rows[index])
            }
        }
        .padding(16)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func row(_ row: Row) -> some View {
        fields(row)
            .contentShape(Rectangle())
            .copyRowMenu(row.value) {
                lifted(row)
            }
    }

    private func lifted(_ row: Row) -> some View {
        fields(row)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    private func fields(_ row: Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            Text(row.label)
                .foregroundStyle(.secondary)

            Text(verbatim: row.value)
                .font(row.monospaced ? .body.monospaced() : .body)
                .lineLimit(row.singleLine ? 1 : nil)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textSelection(.enabled)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1 / displayScale)
            .padding(.vertical, 7)
    }
}
