import CsumController
import SwiftUI

struct CsvTableView: View {
    private enum Layout {
        static let checksum: CGFloat = 120
        static let size: CGFloat = 60
        static let date: CGFloat = 85
        static let path: CGFloat = 170
    }

    let table: CsvTable

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(table.rows) { row in
                    GridRow(alignment: .firstTextBaseline) {
                        cells(for: row)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func cells(for row: CsvTable.Row) -> some View {
        if row.isComment {
            Text(verbatim: row.fields.first ?? "")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .gridCellColumns(max(table.columnCount, 1))
        } else {
            ForEach(Array(row.fields.enumerated()), id: \.offset) { index, field in
                Text(verbatim: field)
                    .font(row.fields.first == "Checksum" ? .footnote.weight(.semibold) : .caption)
                    .foregroundStyle(row.fields.first == "Checksum" ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: width(for: index), alignment: alignment(for: index))
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
