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
                            ForEach(DiffRows.rows(for: section, of: comparison)) { row in
                                entryRow(row)
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
        Button {
            withAnimation(.snappy) {
                if expanded.contains(section) {
                    expanded.remove(section)
                } else {
                    expanded.insert(section)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded.contains(section) ? 90 : 0))
                    .frame(width: Layout.symbol)

                Text(section.displayTitle)
                    .fontWeight(.semibold)

                Text(Format.count(section.count(in: comparison)))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Layout.inset)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.05))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
    }
}
