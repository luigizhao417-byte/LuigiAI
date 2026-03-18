import SwiftUI

@main
struct AgentDeskApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1180, minHeight: 780)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1440, height: 900)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 560, height: 460)
                .preferredColorScheme(.dark)
        }
    }
}
