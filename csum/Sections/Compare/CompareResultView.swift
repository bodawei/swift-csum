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
                    ComparisonTable(comparison: comparison, expanded: $expanded)
                }
            }
        }
    }

    private func sections(_ comparison: ChecksumComparison) -> some View {
        List {
            ForEach(ComparisonSection.allCases, id: \.self) { section in
                if section.count(in: comparison) > 0 {
                    Section {
                        if expanded.contains(section) {
                            ForEach(DiffRows.rows(for: section, of: comparison)) { row in
                                DiffRowView(row: row)
                                    .listRowBackground(row.tint?.background)
                            }
                        }
                    } header: {
                        header(for: section, in: comparison)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func header(for section: ComparisonSection, in comparison: ChecksumComparison)
        -> some View
    {
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
                    .frame(width: 14, alignment: .leading)

                Text(section.displayTitle)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)

                Text(Format.count(section.count(in: comparison)))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("section-\(section.rawValue)")
    }

    private func isIdentical(_ comparison: ChecksumComparison) -> Bool {
        comparison.added.isEmpty
            && comparison.removed.isEmpty
            && comparison.changed.isEmpty
            && comparison.moved.isEmpty
            && comparison.renamed.isEmpty
    }
}
