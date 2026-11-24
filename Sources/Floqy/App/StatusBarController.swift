import AppKit
import SwiftUI

/// Manages Floqy's macOS menu bar item (NSStatusItem) and quick-access menu.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var notchManager: NotchManager?
    private var settingsWindow: NSWindow?

    init(notchManager: NotchManager) {
        self.notchManager = notchManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "Floqy"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Floqy — Notch Hub (⌘⇧Space)"
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Toggle Floqy",
            action: #selector(toggleNotch),
            keyEquivalent: " "
        )
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let stateMenu = NSMenu()
        let idleItem = NSMenuItem(title: "Idle (Closed)", action: #selector(selectIdle), keyEquivalent: "")
        idleItem.target = self
        stateMenu.addItem(idleItem)

        let expandedItem = NSMenuItem(title: "Expanded Hub", action: #selector(selectExpanded), keyEquivalent: "")
        expandedItem.target = self
        stateMenu.addItem(expandedItem)

        stateMenu.addItem(.separator())

        for activity in CompactActivity.allCases {
            let item = NSMenuItem(
                title: "Compact: \(activity.displayName)",
                action: #selector(selectCompactActivity(_:)),
                keyEquivalent: ""
            )
            item.representedObject = activity.rawValue
            item.target = self
            stateMenu.addItem(item)
        }

        let stateRoot = NSMenuItem(title: "Notch State", action: nil, keyEquivalent: "")
        stateRoot.submenu = stateMenu
        menu.addItem(stateRoot)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Floqy",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleNotch() {
        notchManager?.toggleExpanded()
    }

    @objc private func selectIdle() {
        notchManager?.setMode(.idle)
    }

    @objc private func selectExpanded() {
        notchManager?.setMode(.expanded)
    }

    @objc private func selectCompactActivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let activity = CompactActivity(rawValue: raw) else { return }
        notchManager?.showCompact(activity)
    }

    @objc private func openSettings() {
        guard let notchManager else { return }
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 290),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Floqy Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(manager: notchManager))
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
