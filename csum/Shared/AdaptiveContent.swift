import SwiftUI

private let wideContentWidth: CGFloat = 700

struct AdaptiveContent<Compact: View, Wide: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isWide = false

    private let compact: Compact
    private let wide: Wide

    init(
        @ViewBuilder compact: () -> Compact,
        @ViewBuilder wide: () -> Wide
    ) {
        self.compact = compact()
        self.wide = wide()
    }

    var body: some View {
        Group {
            if isWide && horizontalSizeClass != .compact {
                wide
            } else {
                compact
            }
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width >= wideContentWidth
        } action: {
            isWide = $0
        }
    }
}
