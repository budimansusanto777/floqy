import AppKit

/// Application delegate responsible for bootstrapping the NotchManager and menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let notchManager = NotchManager()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier {
            let currentPID = ProcessInfo.processInfo.processIdentifier
            for running in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                where running.processIdentifier != currentPID {
                if !running.terminate() {
                    running.forceTerminate()
                }
            }
        }
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(notchManager: notchManager)
        notchManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.invalidate()
        statusBarController = nil
        notchManager.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            notchManager.handleIncomingURL(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
