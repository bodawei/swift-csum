import SwiftUI
import UIKit

struct RowCopyMenu: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}

extension View {
    func copyRowMenu(_ text: String) -> some View {
        modifier(RowCopyMenu(text: text))
    }
}
