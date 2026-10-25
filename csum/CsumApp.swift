import SwiftUI

#if os(macOS)
    import AppKit
#endif

@main
struct CsumApp: App {
    @State private var model = AppModel()

    #if targetEnvironment(macCatalyst)
        @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        #if os(macOS)
            NSWindow.allowsAutomaticWindowTabbing = false
        #endif

        Telemetry.start()
        Logger.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                #if targetEnvironment(macCatalyst)
                    .onAppear {
                        appDelegate.attach(model: model)
                    }
                #endif
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
