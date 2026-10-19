#if targetEnvironment(macCatalyst)
    import UIKit

    final class AppDelegate: UIResponder, UIApplicationDelegate {
        override func buildMenu(with builder: UIMenuBuilder) {
            super.buildMenu(with: builder)
            builder.remove(menu: UIMenu.Identifier("com.apple.menu.document"))
        }
    }
#endif
