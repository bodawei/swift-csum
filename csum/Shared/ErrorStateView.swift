import SwiftUI

struct ErrorStateView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}
