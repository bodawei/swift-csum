import CsumController
import SwiftUI

struct ChecksumTable: View {
    let result: ChecksumResult

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(result.entries, id: \.path) { entry in
                        row(entry)

                        Divider()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: ResultsTableLayout.spacing) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Size")
                .frame(width: ResultsTableLayout.size, alignment: .trailing)

            Text("Created")
                .frame(width: ResultsTableLayout.date, alignment: .leading)

            Text("Modified")
                .frame(width: ResultsTableLayout.date, alignment: .leading)

            Text("Checksum")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, ResultsTableLayout.inset)
        .padding(.vertical, 6)
    }

    private func row(_ entry: ChecksumEntry) -> some View {
        HStack(spacing: ResultsTableLayout.spacing) {
            Text(verbatim: result.relativePath(of: entry))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: Format.size(entry.size))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: ResultsTableLayout.size, alignment: .trailing)

            Text(verbatim: Format.day(entry.created))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: ResultsTableLayout.date, alignment: .leading)

            Text(verbatim: Format.day(entry.modified))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: ResultsTableLayout.date, alignment: .leading)

            Text(verbatim: Format.checksum(entry))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, ResultsTableLayout.inset)
        .padding(.vertical, ResultsTableLayout.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
