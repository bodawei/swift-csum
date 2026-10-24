#if targetEnvironment(macCatalyst)
    import UIKit

    final class AppDelegate: UIResponder, UIApplicationDelegate {
        private(set) weak var model: AppModel?

        func attach(model: AppModel) {
            self.model = model
        }

        override func buildMenu(with builder: UIMenuBuilder) {
            super.buildMenu(with: builder)
            builder.remove(menu: UIMenu.Identifier("com.apple.menu.document"))
        }

        override func copy(_ sender: Any?) {
            model?.copyResults()
        }

        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            if action == #selector(copy(_:)) {
                return model?.canCopyResults ?? false
            }

            return super.canPerformAction(action, withSender: sender)
        }
    }
#endif
