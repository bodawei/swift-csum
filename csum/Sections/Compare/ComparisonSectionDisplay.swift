import CsumController
import SwiftUI

extension ComparisonSection {
    var displayTitle: LocalizedStringKey {
        switch self {
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

    func count(in comparison: ChecksumComparison) -> Int {
        switch self {
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
}

struct ComparisonSectionHeader: View {
    private enum Layout {
        static let symbol: CGFloat = 14
        static let inset: CGFloat = 16
    }

    let section: ComparisonSection
    let count: Int
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: Layout.symbol)

                Text(section.displayTitle)
                    .fontWeight(.semibold)

                Text(Format.count(count))
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
}
