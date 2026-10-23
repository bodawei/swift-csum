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

    private var share: some View {
        ExportShareLink(export: model.export)
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
                    ComparisonTable(comparison: comparison, expanded: $expanded)
                }
            }
        }
    }

    private func sections(_ comparison: ChecksumComparison) -> some View {
        List {
            ForEach(ComparisonSection.allCases, id: \.self) { section in
                if section.count(in: comparison) > 0 {
                    DisclosureGroup(isExpanded: binding(for: section)) {
                        if expanded.contains(section) {
                            ForEach(DiffRows.rows(for: section, of: comparison)) { row in
                                DiffRowView(row: row)
                                    .listRowBackground(row.tint?.background)
                            }
                        }
                    } label: {
                        HStack {
                            Text(section.displayTitle)

                            Spacer()

                            Text(Format.count(section.count(in: comparison)))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .listStyle(.plain)
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

    private func isIdentical(_ comparison: ChecksumComparison) -> Bool {
        comparison.added.isEmpty
            && comparison.removed.isEmpty
            && comparison.changed.isEmpty
            && comparison.moved.isEmpty
            && comparison.renamed.isEmpty
    }
}
