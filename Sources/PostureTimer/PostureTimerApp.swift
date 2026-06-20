import SwiftUI

@main
struct PostureTimerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)

        SwiftUI.Settings {
            SettingsView(settings: model.settings)
        }
    }
}
