import SwiftUI

enum TableHeader {
    static let font = Font.footnote.weight(.semibold)
}

struct TableColumnDivider: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1 / displayScale, height: 12)
    }
}

extension View {
    func columnDivider(spacing: CGFloat = 12) -> some View {
        overlay(alignment: .leading) {
            TableColumnDivider()
                .offset(x: -spacing / 2)
        }
    }
}
