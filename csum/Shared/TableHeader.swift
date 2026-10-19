import SwiftUI

enum TableHeader {
    static func text(_ title: LocalizedStringKey) -> Text {
        #if targetEnvironment(macCatalyst)
            return Text(title).foregroundStyle(Color.secondary)
        #else
            return Text(title)
        #endif
    }
}
