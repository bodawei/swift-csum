#if targetEnvironment(macCatalyst)
    import SwiftUI
    import UIKit

    struct WindowTitleHider: UIViewRepresentable {
        func makeUIView(context: Context) -> TitleHidingView {
            TitleHidingView()
        }

        func updateUIView(_ view: TitleHidingView, context: Context) {
            view.hideTitle()
        }

        final class TitleHidingView: UIView {
            override func didMoveToWindow() {
                super.didMoveToWindow()

                hideTitle()
            }

            func hideTitle() {
                window?.windowScene?.titlebar?.titleVisibility = .hidden
            }
        }
    }
#endif
