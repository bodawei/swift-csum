import CsumController
import SwiftUI

struct ChecksumTable: View {
    let result: ChecksumResult

    var body: some View {
        List {
            Section {
                ForEach(result.entries.indices, id: \.self) { index in
                    row(result.entries[index])
                        .listRowInsets(EdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20))
                        .listRowBackground(TableStriping.color(forRow: index))
                        .listRowSeparator(.hidden)
                }
            } header: {
                TableHeader()
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 24)
    }

    private func row(_ entry: ChecksumEntry) -> some View {
        TableRowLayout(
            size: Format.size(entry.size),
            created: Format.day(entry.created),
            modified: Format.day(entry.modified),
            name: {
                Text(verbatim: result.relativePath(of: entry))
                    .truncationMode(.middle)
            },
            checksum: {
                Text(verbatim: Format.checksum(entry))
            }
        )
    }
}
