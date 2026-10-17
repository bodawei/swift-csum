import SwiftUI

@main
struct ChecksumApp: App {
    init() {
        Telemetry.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
