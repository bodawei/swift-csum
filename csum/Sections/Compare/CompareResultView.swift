import CsumController
import SwiftUI

struct CompareResultView: View {
    let model: CompareSectionModel

    @State private var expanded: Set<ComparisonSection> = [.added, .removed, .changed]

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
        List {
            Section {
                ForEach(visibleSections(comparison), id: \.self) { section in
                    DisclosureGroup(isExpanded: binding(for: section)) {
                        if expanded.contains(section) {
                            ForEach(
                                Array(DiffRows.rows(for: section, of: comparison).enumerated()),
                                id: \.element.id
                            ) { index, row in
                                wideRow(row)
                                    .listRowInsets(
                                        EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 20)
                                    )
                                    .listRowBackground(TableStriping.color(forRow: index))
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } label: {
                        wideSectionLabel(section, of: comparison)
                    }
                }
            } header: {
                TableHeader()
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 24)
    }

    private func wideSectionLabel(
        _ section: ComparisonSection,
        of comparison: ChecksumComparison
    ) -> some View {
        HStack(spacing: 8) {
            Text(title(for: section))

            Text(Format.count(count(for: section, in: comparison)))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func wideRow(_ row: DiffRow) -> some View {
        TableRowLayout(
            size: row.size,
            created: row.created,
            modified: row.date,
            name: {
                HStack(spacing: 6) {
                    Text(verbatim: row.symbol)
                        .foregroundStyle(row.tint ?? Color.secondary)

                    Text(row.name)
                        .truncationMode(.middle)
                }
            },
            checksum: {
                Text(row.checksum)
            }
        )
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
