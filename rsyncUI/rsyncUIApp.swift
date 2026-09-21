import SwiftUI

@main
struct rsyncUIApp: App {
    var body: some Scene {
        WindowGroup("rsyncUI") {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
