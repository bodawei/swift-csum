import SwiftUI
import ChecksumCore

struct ResultTableView: View {
    let items: [CsvRow]
    let onCopy: () -> Void
    let onSave: () -> Void

    private let columnTitles = ["Filename", "Checksum", "Algorithm", "Size", "Created", "Modified", "Path"]
    private let columnWidths: [CGFloat] = [170, 470, 90, 110, 100, 100, 340]

    private var columns: [(title: String, width: CGFloat)] {
        Array(zip(columnTitles, columnWidths))
    }

    private var tableWidth: CGFloat {
        columnWidths.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                            BorderedCell(width: column.width) {
                                Text(column.title).font(.caption.bold())
                            }
                        }
                    }
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 0) {
                            BorderedCell(width: columnWidths[0]) {
                                Text(item.filename).font(.caption)
                            }
                            checksumCell(item)
                            BorderedCell(width: columnWidths[2]) {
                                Text(item.algorithm).font(.caption)
                            }
                            BorderedCell(width: columnWidths[3]) {
                                Text(item.size).font(.caption)
                            }
                            BorderedCell(width: columnWidths[4]) {
                                Text(item.created).font(.system(.caption, design: .monospaced))
                            }
                            BorderedCell(width: columnWidths[5]) {
                                Text(item.modified).font(.system(.caption, design: .monospaced))
                            }
                            BorderedCell(width: columnWidths[6]) {
                                Text(item.path).font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(width: tableWidth)
            }
            .frame(maxHeight: 400)
            HStack {
                Button("Copy Rows") {
                    onCopy()
                }
                .buttonStyle(.bordered)
                Button("Save CSV…") {
                    onSave()
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func checksumCell(_ item: CsvRow) -> some View {
        if item.checksum.hasPrefix("Error:") {
            BorderedCell(width: columnWidths[1]) {
                Text(item.checksum)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
            }
        } else {
            BorderedCell(width: columnWidths[1]) {
                Text(item.checksum).font(.system(.caption, design: .monospaced))
            }
        }
    }
}
