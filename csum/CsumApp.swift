import SwiftUI

@main
struct CsumApp: App {
    @State private var model = AppModel()

    init() {
        Telemetry.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save As…") {
                    model.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!model.canSaveAs)
            }
        }
    }
}
