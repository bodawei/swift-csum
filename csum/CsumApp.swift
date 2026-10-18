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
    }
}
