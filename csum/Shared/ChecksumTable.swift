import CsumController
import SwiftUI

struct ChecksumTable: View {
    private struct Row: Identifiable {
        let entry: ChecksumEntry

        var id: String {
            entry.path
        }
    }

    let result: ChecksumResult

    var body: some View {
        Table(of: Row.self) {
            TableColumn(TableHeader.text("Name")) { row in
                Text(verbatim: result.relativePath(of: row.entry))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            TableColumn(TableHeader.text("Size")) { row in
                Text(verbatim: Format.size(row.entry.size))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            TableColumn(TableHeader.text("Created")) { row in
                Text(verbatim: Format.day(row.entry.created))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TableColumn(TableHeader.text("Modified")) { row in
                Text(verbatim: Format.day(row.entry.modified))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TableColumn(TableHeader.text("Checksum")) { row in
                Text(verbatim: Format.checksum(row.entry))
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } rows: {
            ForEach(result.entries, id: \.path) { entry in
                TableRow(Row(entry: entry))
            }
        }
    }
}
