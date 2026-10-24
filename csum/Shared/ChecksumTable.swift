import CsumController
import SwiftUI

struct ChecksumTable: View {
    private enum Layout {
        static let inset: CGFloat = 16
        static let spacing: CGFloat = 12
        static let size: CGFloat = 80
        static let date: CGFloat = 110
        static let rowPadding: CGFloat = 6
    }

    let result: ChecksumResult

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(result.entries, id: \.path) { entry in
                        row(entry)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Layout.spacing) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Size")
                .frame(width: Layout.size, alignment: .trailing)
                .columnDivider(spacing: Layout.spacing)

            Text("Created")
                .frame(width: Layout.date, alignment: .leading)
                .columnDivider(spacing: Layout.spacing)

            Text("Modified")
                .frame(width: Layout.date, alignment: .leading)
                .columnDivider(spacing: Layout.spacing)

            Text("Checksum")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .columnDivider(spacing: Layout.spacing)
        }
        .font(TableHeader.font)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, 6)
    }

    private func row(_ entry: ChecksumEntry) -> some View {
        HStack(spacing: Layout.spacing) {
            Text(verbatim: result.relativePath(of: entry))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: Format.size(entry.size))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: Layout.size, alignment: .trailing)

            Text(verbatim: Format.day(entry.created))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: Layout.date, alignment: .leading)

            Text(verbatim: Format.day(entry.modified))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: Layout.date, alignment: .leading)

            Text(verbatim: Format.checksum(entry))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
