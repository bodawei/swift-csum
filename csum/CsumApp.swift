import SwiftUI

#if os(macOS)
    import AppKit
#endif

@main
struct CsumApp: App {
    @State private var model: AppModel

    #if targetEnvironment(macCatalyst)
        @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        AppModelHolder.shared = model

        #if os(macOS)
            NSWindow.allowsAutomaticWindowTabbing = false
        #endif

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

            CommandGroup(replacing: .help) {
                Button("csum Help") {
                    model.showHelp()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
