import AppKit
import SwiftUI

/// Manages Floqy's macOS menu bar item (NSStatusItem) and quick-access menu.
@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private weak var notchManager: NotchManager?
    private var settingsWindow: NSWindow?

    init(notchManager: NotchManager) {
        self.notchManager = notchManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        notchManager.onOpenFullSettings = { [weak self] in
            self?.openSettings()
        }
    }

    func invalidate() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = Self.makeMenuBarPoodleIcon()
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

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

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
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 470),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Floqy Settings"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(manager: notchManager))
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow?.contentView = nil
        settingsWindow = nil
    }

    @objc private func checkForUpdates() {
        notchManager?.checkForUpdates(presentAlert: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func makeMenuBarPoodleIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
                ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }

            func fillSpark(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, angleDeg: CGFloat) {
                ctx.saveGState()
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: angleDeg * .pi / 180)
                let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                let path = CGPath(roundedRect: rect, cornerWidth: w / 2, cornerHeight: w / 2, transform: nil)
                ctx.addPath(path)
                ctx.fillPath()
                ctx.restoreGState()
            }

            ctx.setFillColor(NSColor.black.cgColor)

            // Two signature upper-right sparks from AppIcon
            fillSpark(cx: 13.07, cy: 4.18, w: 1.45, h: 2.95, angleDeg: 20)
            fillSpark(cx: 15.22, cy: 5.70, w: 1.35, h: 2.70, angleDeg: 42)

            // Fluffy curly crown & cheeks
            fillCircle(9.0, 7.5, 2.55)
            fillCircle(6.5, 8.15, 2.05)
            fillCircle(11.5, 8.15, 2.05)
            fillCircle(4.5, 9.55, 1.85)
            fillCircle(13.5, 9.55, 1.85)
            ctx.fillEllipse(in: CGRect(x: 9.0 - 5.35, y: 11.55 - 3.75, width: 10.7, height: 7.5))

            // Flared curly hanging ears
            fillCircle(2.75, 11.35, 1.65)
            fillCircle(1.9, 13.15, 1.45)
            fillCircle(3.35, 14.35, 1.55)
            fillCircle(15.25, 11.35, 1.65)
            fillCircle(16.1, 13.15, 1.45)
            fillCircle(14.65, 14.35, 1.55)

            // Bottom peeking chin & paws
            let chinPath = CGPath(
                roundedRect: CGRect(x: 2.6, y: 12.8, width: 12.8, height: 3.2),
                cornerWidth: 1.5,
                cornerHeight: 1.5,
                transform: nil
            )
            ctx.addPath(chinPath)
            ctx.fillPath()

            // Punch transparent negative-space cutouts for eyes, snout/paw lines, and nose
            ctx.setBlendMode(.clear)
            fillCircle(6.7, 11.65, 1.15)
            fillCircle(11.3, 11.65, 1.15)

            ctx.setLineWidth(0.68)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(NSColor.black.cgColor)

            ctx.move(to: CGPoint(x: 6.9, y: 13.7))
            ctx.addQuadCurve(to: CGPoint(x: 11.1, y: 13.7), control: CGPoint(x: 9.0, y: 12.1))
            ctx.strokePath()

            ctx.move(to: CGPoint(x: 3.0, y: 15.7))
            ctx.addCurve(to: CGPoint(x: 6.75, y: 15.65), control1: CGPoint(x: 2.9, y: 13.7), control2: CGPoint(x: 5.9, y: 13.3))
            ctx.strokePath()

            ctx.move(to: CGPoint(x: 15.0, y: 15.7))
            ctx.addCurve(to: CGPoint(x: 11.25, y: 15.65), control1: CGPoint(x: 15.1, y: 13.7), control2: CGPoint(x: 12.1, y: 13.3))
            ctx.strokePath()

            ctx.fillEllipse(in: CGRect(x: 9.0 - 1.12, y: 13.85 - 0.78, width: 2.24, height: 1.56))

            // Tiny eye catchlights
            ctx.setBlendMode(.normal)
            fillCircle(6.4, 11.2, 0.33)
            fillCircle(11.0, 11.2, 0.33)

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Floqy"
        return image
    }
}
