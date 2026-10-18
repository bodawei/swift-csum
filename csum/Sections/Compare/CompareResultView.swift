import CsumController
import SwiftUI

struct CompareResultView: View {
    let model: CompareSectionModel

    @State private var expanded: Set<ComparisonSection> = [.added, .removed, .changed]

    private enum TableRowItem: Identifiable {
        case section(ComparisonSection, count: Int)
        case entry(DiffRow)

        var id: String {
            switch self {
            case .section(let section, _):
                return "section-\(section.rawValue)"
            case .entry(let row):
                return "entry-\(row.id)"
            }
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    share
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            Color.clear
        case .running:
            ProgressView()
                .controlSize(.large)
        case .loaded(let comparison):
            results(comparison)
        case .failed(let message):
            ErrorStateView(message: message)
        }
    }

    @ViewBuilder
    private var share: some View {
        if let export = model.export {
            ShareLink(item: export, preview: SharePreview(export.fileName)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(true)
        }
    }

    private func results(_ comparison: ChecksumComparison) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MetadataStrip(
                path: "\(comparison.metadata.first.path) → \(comparison.metadata.second.path)",
                detail:
                    "Computed \(Format.timestamp(comparison.metadata.first.computedAt)) and \(Format.timestamp(comparison.metadata.second.computedAt)) · Format \(comparison.metadata.formatVersion)"
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if isIdentical(comparison) {
                ContentUnavailableView("No differences", systemImage: "checkmark.circle")
            } else {
                AdaptiveContent {
                    sections(comparison)
                } wide: {
                    wideSections(comparison)
                }
            }
        }
    }

    private func sections(_ comparison: ChecksumComparison) -> some View {
        List {
            ForEach(ComparisonSection.allCases, id: \.self) { section in
                if count(for: section, in: comparison) > 0 {
                    DisclosureGroup(isExpanded: binding(for: section)) {
                        if expanded.contains(section) {
                            ForEach(DiffRows.rows(for: section, of: comparison)) { row in
                                DiffRowView(row: row)
                                    .listRowBackground(row.tint?.opacity(0.08))
                            }
                        }
                    } label: {
                        HStack {
                            Text(title(for: section))

                            Spacer()

                            Text(Format.count(count(for: section, in: comparison)))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func wideSections(_ comparison: ChecksumComparison) -> some View {
        Table(of: TableRowItem.self) {
            TableColumn("Name") { item in
                switch item {
                case .section(let section, let count):
                    HStack(spacing: 8) {
                        Text(title(for: section))
                        Text(Format.count(count))
                            .foregroundStyle(.secondary)
                    }
                case .entry(let row):
                    HStack(spacing: 6) {
                        Text(verbatim: row.symbol)
                            .foregroundStyle(row.tint ?? Color.secondary)
                        Text(row.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            TableColumn("Size") { item in
                value(item) { $0.size }
            }

            TableColumn("Created") { item in
                value(item) { $0.created }
            }

            TableColumn("Modified") { item in
                value(item) { $0.date }
            }

            TableColumn("Checksum") { item in
                if case .entry(let row) = item {
                    Text(row.checksum)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } rows: {
            ForEach(visibleSections(comparison), id: \.self) { section in
                DisclosureTableRow(
                    TableRowItem.section(section, count: count(for: section, in: comparison)),
                    isExpanded: binding(for: section)
                ) {
                    ForEach(DiffRows.rows(for: section, of: comparison)) { row in
                        TableRow(TableRowItem.entry(row))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func value(_ item: TableRowItem, of row: (DiffRow) -> String) -> some View {
        if case .entry(let diff) = item {
            Text(verbatim: row(diff))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func visibleSections(_ comparison: ChecksumComparison) -> [ComparisonSection] {
        ComparisonSection.allCases.filter { count(for: $0, in: comparison) > 0 }
    }

    private func binding(for section: ComparisonSection) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expanded.insert(section)
                } else {
                    expanded.remove(section)
                }
            }
        )
    }

    private func count(for section: ComparisonSection, in comparison: ChecksumComparison) -> Int {
        switch section {
        case .added:
            return comparison.added.count
        case .removed:
            return comparison.removed.count
        case .changed:
            return comparison.changed.count
        case .moved:
            return comparison.moved.count
        case .renamed:
            return comparison.renamed.count
        case .unchanged:
            return comparison.unchanged.count
        }
    }

    private func title(for section: ComparisonSection) -> LocalizedStringKey {
        switch section {
        case .added:
            return "Added"
        case .removed:
            return "Removed"
        case .changed:
            return "Changed"
        case .moved:
            return "Moved"
        case .renamed:
            return "Renamed"
        case .unchanged:
            return "Unchanged"
        }
    }

    private func isIdentical(_ comparison: ChecksumComparison) -> Bool {
        comparison.added.isEmpty
            && comparison.removed.isEmpty
            && comparison.changed.isEmpty
            && comparison.moved.isEmpty
            && comparison.renamed.isEmpty
    }
}
