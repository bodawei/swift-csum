import SwiftUI
import UIKit

struct RowCopyMenu<Preview: View>: ViewModifier {
    let text: String
    let preview: (() -> Preview)?

    func body(content: Content) -> some View {
        if let preview {
            content.contextMenu {
                copy
            } preview: {
                preview()
            }
        } else {
            content.contextMenu {
                copy
            }
        }
    }

    private var copy: some View {
        Button {
            UIPasteboard.general.string = text
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }
}

extension View {
    func copyRowMenu(_ text: String) -> some View {
        modifier(RowCopyMenu<EmptyView>(text: text, preview: nil))
    }

    func copyRowMenu<Preview: View>(
        _ text: String,
        @ViewBuilder preview: @escaping () -> Preview
    ) -> some View {
        modifier(RowCopyMenu(text: text, preview: preview))
    }
}
