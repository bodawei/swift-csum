import CsumController
import SwiftUI

struct ComparisonTable: View {
    private enum Layout {
        static let inset: CGFloat = 16
        static let spacing: CGFloat = 12
        static let symbol: CGFloat = 14
        static let size: CGFloat = 80
        static let date: CGFloat = 120
        static let rowPadding: CGFloat = 6
    }

    let comparison: ChecksumComparison

    @Binding var expanded: Set<ComparisonSection>

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleSections, id: \.self) { section in
                        sectionRow(section)

                        if expanded.contains(section) {
                            let rowCount = DiffRows.rowCount(for: section, of: comparison)

                            ForEach(0..<rowCount, id: \.self) { index in
                                entryRow(DiffRows.row(at: index, in: section, of: comparison))
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var visibleSections: [ComparisonSection] {
        ComparisonSection.allCases.filter { $0.count(in: comparison) > 0 }
    }

    private var header: some View {
        HStack(spacing: Layout.spacing) {
            Color.clear
                .frame(width: Layout.symbol, height: 0)

            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Size")
                .frame(width: Layout.size, alignment: .trailing)

            Text("Created")
                .frame(width: Layout.date, alignment: .leading)

            Text("Modified")
                .frame(width: Layout.date, alignment: .leading)

            Text("Checksum")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(TableHeader.font)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, 6)
    }

    private func sectionRow(_ section: ComparisonSection) -> some View {
        ComparisonSectionHeader(
            section: section,
            count: section.count(in: comparison),
            expanded: $expanded
        )
    }

    private func entryRow(_ row: DiffRow) -> some View {
        HStack(spacing: Layout.spacing) {
            Text(verbatim: row.symbol)
                .fontWeight(.semibold)
                .frame(width: Layout.symbol, alignment: .leading)

            Text(row.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: row.size)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: Layout.size, alignment: .trailing)

            Text(verbatim: row.created)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: Layout.date, alignment: .leading)

            Text(verbatim: row.date)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: Layout.date, alignment: .leading)

            Text(row.checksum)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(row.tint?.background ?? Color.clear)
        .copyRowMenu(row.csv)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
    }
}
