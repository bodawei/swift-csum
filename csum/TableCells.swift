import SwiftUI

struct BorderedCell<Content: View>: View {
    let width: CGFloat
    let content: Content

    init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        content
            .padding(6)
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
            .textSelection(.enabled)
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4)))
    }
}

func cellFont(_ title: String) -> Font {
    switch title {
    case "Checksum", "Path", "From", "To", "Old Checksum", "New Checksum", "Created", "Modified":
        return .system(.caption, design: .monospaced)
    default:
        return .caption
    }
}

extension View {
    func dropHighlight(_ targeted: Bool) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
                .opacity(targeted ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: targeted)
        )
    }
}
