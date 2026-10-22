import CsumController
import SwiftUI

struct ComparisonTable: View {
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
        HStack(spacing: ResultsTableLayout.spacing) {
            Color.clear
                .frame(width: ResultsTableLayout.symbol, height: 0)

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
                    .frame(width: ResultsTableLayout.symbol)

                Text(section.displayTitle)
                    .fontWeight(.semibold)

                Text(Format.count(section.count(in: comparison)))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, ResultsTableLayout.inset)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.05))
    }

    private func entryRow(_ row: DiffRow) -> some View {
        HStack(spacing: ResultsTableLayout.spacing) {
            Text(verbatim: row.symbol)
                .fontWeight(.semibold)
                .foregroundStyle(row.tint ?? Color.secondary)
                .frame(width: ResultsTableLayout.symbol, alignment: .leading)

            Text(row.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: row.size)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: ResultsTableLayout.size, alignment: .trailing)

            Text(verbatim: row.created)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: ResultsTableLayout.date, alignment: .leading)

            Text(verbatim: row.date)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: ResultsTableLayout.date, alignment: .leading)

            Text(row.checksum)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, ResultsTableLayout.inset)
        .padding(.vertical, ResultsTableLayout.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(row.tint?.opacity(0.08) ?? Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
    }
}
