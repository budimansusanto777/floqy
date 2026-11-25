import AppKit

/// Application delegate responsible for bootstrapping the NotchManager and menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let notchManager = NotchManager()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(notchManager: notchManager)
        notchManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchManager.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
