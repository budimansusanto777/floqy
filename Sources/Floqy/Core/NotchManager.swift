import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Central coordinator for notch state, hover debounce, screen geometry, and global hotkeys.
@MainActor
final class NotchManager: ObservableObject {
    @Published var mode: NotchMode = .idle
    @Published var activeTab: NotchTab = .home
    @Published var compactActivity: CompactActivity = .music
    @Published var hoverToExpandEnabled: Bool = true
    @Published var droppedFileNames: [String] = []
    @Published var toastMessage: String?
    @Published private(set) var geometry: NotchGeometry

    private var panel: NotchPanel?
    private var updateTrackingRect: (() -> Void)?
    private var panelShrinkTask: Task<Void, Never>?
    private var hoverTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var screenObserver: NSObjectProtocol?
    private var lastNonExpandedMode: NotchMode = .idle

    init() {
        self.geometry = NotchGeometry(screen: NotchGeometry.preferredScreen())
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func start() {
        setupPanel()
        observeScreenChanges()
        registerGlobalHotKey()
    }

    // MARK: - State Transitions

    func setMode(_ newMode: NotchMode) {
        hoverTask?.cancel()
        panelShrinkTask?.cancel()

        if !newMode.isExpanded {
            lastNonExpandedMode = newMode
        }
        if case .compact(let activity) = newMode {
            compactActivity = activity
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let targetFrame = geometry.panelFrame(for: newMode)
        let currentFrame = panel?.frame ?? targetFrame
        let isGrowing = targetFrame.width > currentFrame.width || targetFrame.height > currentFrame.height

        if isGrowing {
            // Grow the window immediately before animating so SwiftUI never clips during expansion.
            panel?.setFrame(targetFrame, display: true)
        }

        let animation: Animation = reduceMotion
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.42, dampingFraction: 0.82)

        withAnimation(animation) {
            mode = newMode
        }
        syncPanelFocusAbility()
        updateTrackingRect?()

        if !isGrowing && targetFrame != currentFrame {
            // Shrink the NSWindow after collapse completes so idle never covers browser toolbars below the notch.
            let shrinkDelayNs: UInt64 = reduceMotion ? 170_000_000 : 280_000_000
            panelShrinkTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: shrinkDelayNs)
                guard !Task.isCancelled, let self else { return }
                self.panel?.setFrame(self.geometry.panelFrame(for: self.mode), display: false)
                self.updateTrackingRect?()
            }
        }
    }

    func toggleExpanded() {
        if mode.isExpanded {
            collapse()
        } else {
            setMode(.expanded)
        }
    }

    func collapse() {
        setMode(lastNonExpandedMode)
    }

    func selectTab(_ tab: NotchTab) {
        activeTab = tab
        if !mode.isExpanded {
            setMode(.expanded)
        }
    }

    func showCompact(_ activity: CompactActivity) {
        compactActivity = activity
        setMode(.compact(activity))
    }

    func handleHoverChanged(_ hovering: Bool) {
        guard hoverToExpandEnabled else { return }
        hoverTask?.cancel()

        if hovering {
            guard !mode.isExpanded else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                self?.setMode(.expanded)
            }
        } else {
            guard mode.isExpanded else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                self?.collapse()
            }
        }
    }

    // MARK: - Phase 0 File Staging

    func addDroppedFiles(_ urls: [URL]) {
        let names = urls.map(\.lastPathComponent).filter { !$0.isEmpty }
        guard !names.isEmpty else { return }
        for name in names where !droppedFileNames.contains(name) {
            droppedFileNames.insert(name, at: 0)
        }
        selectTab(.files)
        showToast(names.count == 1 ? "Staged \(names[0])" : "Staged \(names.count) files")
    }

    func removeDroppedFile(at index: Int) {
        guard droppedFileNames.indices.contains(index) else { return }
        droppedFileNames.remove(at: index)
    }

    func clearDroppedFiles() {
        droppedFileNames.removeAll()
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            toastMessage = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                self?.toastMessage = nil
            }
        }
    }

    // MARK: - Window Management

    private func setupPanel() {
        guard panel == nil else { return }
        refreshGeometry()

        let initialFrame = geometry.panelFrame(for: mode)
        let notchPanel = NotchPanel(contentRect: initialFrame)
        notchPanel.onCancel = { [weak self] in
            self?.collapse()
        }

        let container = NotchPassthroughContainerView(
            rootView: NotchRootView(manager: self),
            frame: CGRect(origin: .zero, size: initialFrame.size),
            activeHitRectProvider: { [weak self] size in
                guard let self else { return .zero }
                return self.geometry.hitRectInPanel(for: self.mode, in: size)
            }
        )
        container.onHoverChanged = { [weak self] hovering in
            self?.handleHoverChanged(hovering)
        }
        self.updateTrackingRect = { [weak container] in
            container?.updateTrackingRect()
        }

        notchPanel.contentView = container
        notchPanel.orderFrontRegardless()
        self.panel = notchPanel
        syncPanelFocusAbility()
    }

    private func syncPanelFocusAbility() {
        // Phase 2+: enable allowsKeyFocus only when the user clicks into an editable text field.
        panel?.allowsKeyFocus = false
        if !mode.isExpanded, panel?.isKeyWindow == true {
            panel?.resignKey()
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshGeometry()
                self.panel?.setFrame(self.geometry.panelFrame(for: self.mode), display: true)
                self.updateTrackingRect?()
            }
        }
    }

    private func refreshGeometry() {
        geometry = NotchGeometry(screen: NotchGeometry.preferredScreen())
    }

    // MARK: - Global Shortcut (Cmd + Shift + Space)

    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<NotchManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.toggleExpanded()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard status == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x464C_5159), id: 1) // 'FLQY'
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
