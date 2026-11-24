import SwiftUI

@main
struct FloqyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(manager: appDelegate.notchManager)
        }
    }
}
