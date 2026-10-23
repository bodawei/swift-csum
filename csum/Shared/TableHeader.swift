import SwiftUI

enum TableHeader {
    static let font = Font.footnote.weight(.semibold)

    static func text(_ title: LocalizedStringKey) -> Text {
        let text = Text(title).font(font)

        #if targetEnvironment(macCatalyst)
            return text.foregroundStyle(Color.secondary)
        #else
            return text
        #endif
    }
}
