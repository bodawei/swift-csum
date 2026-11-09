import CsumController
import SwiftUI

struct CsvTableView: View {
    private enum Layout {
        static let checksum: CGFloat = 120
        static let size: CGFloat = 60
        static let date: CGFloat = 85
        static let path: CGFloat = 170
        static let spacing: CGFloat = 12
    }

    let table: CsvTable

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(table.rows) { row in
                        rowView(row)
                            .padding(.vertical, 3)
                            .frame(minWidth: max(proxy.size.width - 40, 0), alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: CsvTable.Row) -> some View {
        if row.isComment {
            Text(verbatim: row.fields.first ?? "")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let isHeader = row.fields.first == "Checksum"

            HStack(spacing: Layout.spacing) {
                ForEach(Array(row.fields.enumerated()), id: \.offset) { index, field in
                    Text(verbatim: field)
                        .font(isHeader ? .footnote.weight(.semibold) : .caption)
                        .foregroundStyle(isHeader ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: width(for: index), alignment: alignment(for: index))
                }
            }
        }
    }

    private func width(for index: Int) -> CGFloat {
        switch index % 5 {
        case 0:
            return Layout.checksum

        case 1:
            return Layout.size

        default:
            return index % 5 == 4 ? Layout.path : Layout.date
        }
    }

    private func alignment(for index: Int) -> Alignment {
        index % 5 == 1 ? .trailing : .leading
    }
}
