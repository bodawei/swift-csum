import SwiftUI
import UIKit

struct DiffTint {
    let marker: Color
    let background: Color
    let emphasis: Color
}

extension DiffTint {
    static let added = DiffTint(
        marker: Color(light: 0x1A7F37, dark: 0x3FB950),
        background: Color(light: 0xDAFBE1, dark: 0x12261E),
        emphasis: Color(light: 0xACEEBB, dark: 0x1D572D)
    )

    static let removed = DiffTint(
        marker: Color(light: 0xD1242F, dark: 0xF85149),
        background: Color(light: 0xFFEBE9, dark: 0x24171C),
        emphasis: Color(light: 0xFFCECB, dark: 0x792E2E)
    )
}

extension Color {
    fileprivate init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
