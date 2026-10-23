import SwiftUI

struct CopyResultsButton: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            app.copyResults()
        } label: {
            Label("Copy Results", systemImage: "doc.on.doc")
        }
        .accessibilityIdentifier("copyResults")
        .disabled(!app.canCopyResults)
    }
}
