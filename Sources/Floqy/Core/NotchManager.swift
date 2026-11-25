import AppKit
import Carbon.HIToolbox
import Combine
import QuartzCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct MeetingHeadsUp: Equatable {
    let event: CalendarEventItem
    let minutesRemaining: Int
}

/// Central coordinator for notch state, hover debounce, screen geometry, global hotkeys, and module services.
@MainActor
final class NotchManager: ObservableObject {
    private static let alertSoundsKey = "floqy.notifications.soundsEnabled"
    private static let showPausedPomodoroKey = "floqy.pomodoro.showPausedInNotch"
    private static let ramAlertEnabledKey = "floqy.system.ramAlertEnabled"
    private static let restingEyesEnabledKey = "floqy.notch.restingEyesEnabled"
    private static let idleAppearanceKey = "floqy.notch.idleAppearance"
    private static let idleWidthKey = "floqy.notch.idleWidth"
    private static let themePresetKey = "floqy.notch.themePreset"
    private static let displayPreferenceKey = "floqy.display.preference"
    private static let headphonesCardEnabledKey = "floqy.hardware.headphonesCardEnabled"
    private static let chargingCardEnabledKey = "floqy.hardware.chargingCardEnabled"

    @Published var mode: NotchMode = .idle {
        didSet {
            NotchColors.activePreset = effectiveThemePreset
        }
    }
    @Published var activeTab: NotchTab = .home
    @Published var homeSubView: HomeSubView = .overview
    @Published var compactActivity: CompactActivity = .music
    @Published var isShowingInlineSettings: Bool = false
    @Published var hoverToExpandEnabled: Bool = true
    @Published var alertSoundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(alertSoundsEnabled, forKey: Self.alertSoundsKey)
        }
    }
    @Published var showPausedPomodoroInNotch: Bool {
        didSet {
            UserDefaults.standard.set(showPausedPomodoroInNotch, forKey: Self.showPausedPomodoroKey)
            syncCollapsedMode()
        }
    }
    @Published var ramAlertEnabled: Bool {
        didSet {
            UserDefaults.standard.set(ramAlertEnabled, forKey: Self.ramAlertEnabledKey)
            syncCollapsedMode()
        }
    }
    @Published var idleAppearance: IdleAppearance {
        didSet {
            UserDefaults.standard.set(idleAppearance.rawValue, forKey: Self.idleAppearanceKey)
            if case .idle = mode {
                applyPanelFrame(for: .idle, tab: activeTab, subView: homeSubView) {}
            }
        }
    }
    @Published var idleWidth: IdleNotchWidth {
        didSet {
            UserDefaults.standard.set(idleWidth.rawValue, forKey: Self.idleWidthKey)
            if case .idle = mode {
                applyPanelFrame(for: .idle, tab: activeTab, subView: homeSubView) {}
            }
        }
    }
    @Published var themePreset: NotchThemePreset {
        didSet {
            NotchColors.activePreset = effectiveThemePreset
            UserDefaults.standard.set(themePreset.rawValue, forKey: Self.themePresetKey)
        }
    }
    @Published var displayPreference: DisplayPreference {
        didSet {
            UserDefaults.standard.set(displayPreference.rawValue, forKey: Self.displayPreferenceKey)
            relocateToPreferredScreen()
            syncCursorScreenMonitor()
        }
    }
    @Published private(set) var launchAtLoginEnabled: Bool = false
    @Published private(set) var launchAtLoginNeedsApproval: Bool = false
    @Published private(set) var launchAtLoginError: String?
    var effectiveThemePreset: NotchThemePreset {
        NotchThemePreset.resolved(for: mode, selected: themePreset)
    }
    @Published private(set) var wallpaperImage: NSImage?

    var restingEyesEnabled: Bool {
        idleAppearance.isVisible
    }
    @Published var headphonesCardEnabled: Bool {
        didSet {
            UserDefaults.standard.set(headphonesCardEnabled, forKey: Self.headphonesCardEnabledKey)
        }
    }
    @Published var chargingCardEnabled: Bool {
        didSet {
            UserDefaults.standard.set(chargingCardEnabled, forKey: Self.chargingCardEnabledKey)
        }
    }
    @Published var isEditingText: Bool = false
    @Published var isDragTargeted: Bool = false
    @Published var toastMessage: String?
    @Published private(set) var activeAlert: NotchAlert?
    @Published private(set) var idleHappyUntil: Date?
    @Published private(set) var meetingHeadsUp: MeetingHeadsUp?
    @Published private(set) var geometry: NotchGeometry

    let music = MusicService()
    let calendar = CalendarService()
    let productivity = ProductivityService()
    let filesTray = FilesTrayService()
    let obsidian = ObsidianService()
    let clipboard = ClipboardService()
    let system = SystemMonitorService()
    let ai = AIService()
    let hardware = HardwareStatusService()

    var onOpenFullSettings: (() -> Void)?

    private var panel: NotchPanel?
    private var updateTrackingRect: (() -> Void)?
    private var panelShrinkTask: Task<Void, Never>?
    private var hoverTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var alertAutoDismissTask: Task<Void, Never>?
    private var triggeredStartingMeetingIDs: Set<String> = []
    private(set) var isHoveringCompactControls: Bool = false
    private var isTrackingMenu: Bool = false
    private var isPresentingFilePicker: Bool = false
    private var cursorScreenMonitor: Any?
    private var lastCursorScreenCheck: CFTimeInterval = 0
    private var cancellables: Set<AnyCancellable> = []
    private var toggleHotKeyRef: EventHotKeyRef?
    private var clipboardHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var screenObserver: NSObjectProtocol?
    private var menuBeginObserver: NSObjectProtocol?
    private var menuEndObserver: NSObjectProtocol?
    private var lastNonExpandedMode: NotchMode = .idle

    init() {
        self.alertSoundsEnabled = UserDefaults.standard.object(forKey: Self.alertSoundsKey) as? Bool ?? true
        self.showPausedPomodoroInNotch = UserDefaults.standard.object(forKey: Self.showPausedPomodoroKey) as? Bool ?? true
        self.ramAlertEnabled = UserDefaults.standard.object(forKey: Self.ramAlertEnabledKey) as? Bool ?? true
        if let savedRaw = UserDefaults.standard.string(forKey: Self.idleAppearanceKey),
           let savedAppearance = IdleAppearance(rawValue: savedRaw) {
            self.idleAppearance = savedAppearance
        } else if let legacyEyes = UserDefaults.standard.object(forKey: Self.restingEyesEnabledKey) as? Bool,
                  !legacyEyes {
            self.idleAppearance = .off
        } else {
            self.idleAppearance = .eyes
        }
        if let savedWidthRaw = UserDefaults.standard.string(forKey: Self.idleWidthKey),
           let savedWidth = IdleNotchWidth(rawValue: savedWidthRaw) {
            self.idleWidth = savedWidth
        } else {
            self.idleWidth = .compact
        }
        let initialTheme: NotchThemePreset
        if let savedThemeRaw = UserDefaults.standard.string(forKey: Self.themePresetKey),
           let savedTheme = NotchThemePreset(rawValue: savedThemeRaw) {
            initialTheme = savedTheme
        } else {
            initialTheme = .obsidian
        }
        let initialDisplayPref: DisplayPreference
        if let savedDisplayRaw = UserDefaults.standard.string(forKey: Self.displayPreferenceKey),
           let savedDisplay = DisplayPreference(rawValue: savedDisplayRaw) {
            initialDisplayPref = savedDisplay
        } else {
            initialDisplayPref = .builtInNotch
        }
        self.displayPreference = initialDisplayPref
        self.themePreset = initialTheme
        self.wallpaperImage = NSImage(contentsOf: Self.wallpaperStorageURL)
        self.headphonesCardEnabled = UserDefaults.standard.object(forKey: Self.headphonesCardEnabledKey) as? Bool ?? true
        self.chargingCardEnabled = UserDefaults.standard.object(forKey: Self.chargingCardEnabledKey) as? Bool ?? true
        self.geometry = NotchGeometry(screen: NotchGeometry.preferredScreen(for: initialDisplayPref))
        NotchColors.activePreset = NotchThemePreset.resolved(for: mode, selected: initialTheme)
        refreshLaunchAtLoginStatus()
    }

    deinit {
        if let cursorScreenMonitor {
            NSEvent.removeMonitor(cursorScreenMonitor)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let menuBeginObserver {
            NotificationCenter.default.removeObserver(menuBeginObserver)
        }
        if let menuEndObserver {
            NotificationCenter.default.removeObserver(menuEndObserver)
        }
        if let toggleHotKeyRef {
            UnregisterEventHotKey(toggleHotKeyRef)
        }
        if let clipboardHotKeyRef {
            UnregisterEventHotKey(clipboardHotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func start() {
        setupPanel()
        observeScreenChanges()
        observeMenuTracking()
        syncCursorScreenMonitor()
        registerGlobalHotKeys()
        startServices()
    }

    func stop() {
        if let cursorScreenMonitor {
            NSEvent.removeMonitor(cursorScreenMonitor)
            self.cursorScreenMonitor = nil
        }
        hardware.stop()
        ai.stop()
        system.stop()
        music.stop()
        calendar.stop()
        clipboard.stop()
    }

    private func startServices() {
        productivity.onPomodoroStarted = { [weak self] in
            self?.compactActivity = .pomodoro
            self?.syncCollapsedMode()
        }
        productivity.onPomodoroStateChanged = { [weak self] in
            self?.syncCollapsedMode()
        }
        productivity.onPomodoroCompleted = { [weak self] in
            self?.triggerPomodoroCompletedAlert()
        }

        system.onStateChanged = { [weak self] in
            self?.syncCollapsedMode()
        }

        ai.onStateChanged = { [weak self] in
            self?.syncCollapsedMode()
        }
        ai.onAgentFinished = { [weak self] agent in
            self?.triggerAIFinishedAlert(agent: agent)
        }

        hardware.onHeadphonesConnected = { [weak self] status in
            self?.triggerHeadphonesConnectedAlert(status)
        }
        hardware.onChargingConnected = { [weak self] status in
            self?.triggerChargingConnectedAlert(status)
        }

        music.$track
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncCollapsedMode()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(calendar.$upcomingEvents, calendar.$now)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.evaluateMeetingAlerts()
            }
            .store(in: &cancellables)

        music.start()
        calendar.start()
        clipboard.start()
        system.start()
        ai.start()
        hardware.start()
    }

    // MARK: - State Transitions

    func setMode(_ newMode: NotchMode) {
        hoverTask?.cancel()

        if !newMode.isCompact {
            isHoveringCompactControls = false
        }
        if !newMode.isExpanded {
            lastNonExpandedMode = newMode
            isShowingInlineSettings = false
            if isEditingText {
                endTextInput()
            }
        }
        if case .compact(let activity) = newMode {
            compactActivity = activity
        }

        system.setSystemTabVisible(newMode.isExpanded && !isShowingInlineSettings && activeTab == .system)

        let effectiveSubView: HomeSubView = (newMode.isExpanded && isShowingInlineSettings) ? .overview : homeSubView
        applyPanelFrame(for: newMode, tab: activeTab, subView: effectiveSubView) {
            mode = newMode
        }
    }

    func setHomeSubView(_ subView: HomeSubView) {
        guard subView != homeSubView else { return }
        let effectiveSubView: HomeSubView = (mode.isExpanded && isShowingInlineSettings) ? .overview : subView
        applyPanelFrame(for: mode, tab: activeTab, subView: effectiveSubView) {
            homeSubView = subView
        }
    }

    func selectTab(_ tab: NotchTab) {
        if isEditingText && (tab != activeTab || isShowingInlineSettings) {
            endTextInput()
        }
        let targetMode: NotchMode = mode.isExpanded ? mode : .expanded
        system.setSystemTabVisible(targetMode.isExpanded && tab == .system)
        applyPanelFrame(for: targetMode, tab: tab, subView: homeSubView) {
            isShowingInlineSettings = false
            activeTab = tab
            if !mode.isExpanded {
                mode = .expanded
            }
        }
    }

    func toggleInlineSettings() {
        if isEditingText {
            endTextInput()
        }
        let targetMode: NotchMode = mode.isExpanded ? mode : .expanded
        let showSettings = !mode.isExpanded ? true : !isShowingInlineSettings
        let effectiveSubView: HomeSubView = showSettings ? .overview : homeSubView
        system.setSystemTabVisible(!showSettings && activeTab == .system)
        applyPanelFrame(for: targetMode, tab: activeTab, subView: effectiveSubView) {
            isShowingInlineSettings = showSettings
            if !mode.isExpanded {
                mode = .expanded
            }
        }
    }

    private func applyPanelFrame(
        for targetMode: NotchMode,
        tab: NotchTab,
        subView: HomeSubView,
        stateMutation: () -> Void
    ) {
        panelShrinkTask?.cancel()

        let latestGeometry = NotchGeometry(screen: NotchGeometry.preferredScreen(for: displayPreference))
        if latestGeometry != geometry {
            geometry = latestGeometry
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let targetFrame = geometry.panelFrame(
            for: targetMode,
            homeSubView: subView,
            activeTab: tab,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        )
        let currentFrame = panel?.frame ?? targetFrame
        let isGrowing = targetFrame.width > currentFrame.width || targetFrame.height > currentFrame.height
        let isOffCenter = abs(currentFrame.midX - geometry.screenFrame.midX) > 1
            || abs(currentFrame.maxY - geometry.screenFrame.maxY) > 1

        if isGrowing || isOffCenter {
            // Grow (or re-center) atomically before animating so SwiftUI never clips or drifts off center.
            let immediateSize = isGrowing
                ? CGSize(
                    width: max(currentFrame.width, targetFrame.width),
                    height: max(currentFrame.height, targetFrame.height)
                )
                : targetFrame.size
            resizePanelAtomically(to: geometry.centeredFrame(size: immediateSize))
        }

        // Mutate state outside withAnimation so outgoing mode views tear down immediately while only the shell animates.
        stateMutation()
        syncPanelFocusAbility()
        updateTrackingRect?()

        if (panel?.frame ?? targetFrame) != targetFrame {
            // Wait until the closing spring finishes before shrinking the NSWindow to its final bounds.
            let shrinkDelayNs: UInt64 = reduceMotion ? 180_000_000 : 340_000_000
            panelShrinkTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: shrinkDelayNs)
                guard !Task.isCancelled, let self else { return }
                let finalSubView: HomeSubView = (self.mode.isExpanded && self.isShowingInlineSettings) ? .overview : self.homeSubView
                let finalFrame = self.geometry.panelFrame(
                    for: self.mode,
                    homeSubView: finalSubView,
                    activeTab: self.activeTab,
                    idleAppearance: self.idleAppearance,
                    idleWidth: self.idleWidth
                )
                self.resizePanelAtomically(to: finalFrame)
                self.updateTrackingRect?()
            }
        }
    }

    private func resizePanelAtomically(to frame: CGRect) {
        guard let panel else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(frame, display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.needsDisplay = true
        panel.displayIfNeeded()
        CATransaction.commit()
        CATransaction.flush()
    }

    func toggleExpanded() {
        if mode.isExpanded {
            collapse()
        } else {
            setMode(.expanded)
        }
    }

    func collapse() {
        if isEditingText {
            endTextInput()
        }
        syncCollapsedMode()
        setMode(lastNonExpandedMode)
    }

    func showCompact(_ activity: CompactActivity) {
        compactActivity = activity
        setMode(.compact(activity))
    }

    // MARK: - Live Activity Priority & Alerts

    func syncCollapsedMode() {
        let isMemoryAlert = ramAlertEnabled && system.snapshot.usedPercent >= SystemLogic.ramAlertThresholdPercent
        let desired = NotchMode.resolvedCollapsedMode(
            activeAlert: activeAlert,
            hasMeetingHeadsUp: meetingHeadsUp != nil,
            pomodoroRunning: productivity.pomodoro.isRunning,
            pomodoroPaused: productivity.pomodoro.isPaused,
            showPausedPomodoroInNotch: showPausedPomodoroInNotch,
            hasActiveAIWork: ai.workingAgent != nil,
            isMemoryAlertActive: isMemoryAlert,
            isMusicPlaying: music.track?.isPlaying == true
        )
        lastNonExpandedMode = desired
        if !mode.isExpanded && mode != desired {
            setMode(desired)
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard let event = AIActivityLogic.parseIncomingURL(url) else { return }
        ai.handleEvent(event)
    }

    func openAgentFromAlert(_ agent: AIAgentKind) {
        ai.openAgentApp(agent)
        dismissActiveAlert()
    }

    func triggerAIFinishedAlert(agent: AIAgentKind) {
        if alertSoundsEnabled {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
        idleHappyUntil = Date().addingTimeInterval(6)
        activeAlert = .aiFinished(agent: agent)
        scheduleAlertAutoDismiss(after: 4.0)
        if mode.isExpanded {
            showToast("\(agent.displayName) finished")
        }
        syncCollapsedMode()
    }

    func triggerHeadphonesConnectedAlert(_ status: HeadphoneStatus) {
        guard headphonesCardEnabled else { return }
        activeAlert = .headphonesConnected(
            name: status.name,
            batteryPercent: status.batteryPercent,
            isAirPods: status.isAirPods
        )
        scheduleAlertAutoDismiss(after: 4.0)
        if mode.isExpanded {
            showToast("\(status.name) connected")
        }
        syncCollapsedMode()
    }

    func triggerChargingConnectedAlert(_ status: BatteryStatus) {
        guard chargingCardEnabled else { return }
        activeAlert = .chargingConnected(
            batteryPercent: status.percentage,
            etaText: status.formattedETA
        )
        scheduleAlertAutoDismiss(after: 4.0)
        if mode.isExpanded {
            showToast("Charging · \(status.percentage)%")
        }
        syncCollapsedMode()
    }

    func triggerPomodoroCompletedAlert() {
        if alertSoundsEnabled {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
        idleHappyUntil = Date().addingTimeInterval(6)
        activeAlert = .pomodoroComplete(durationMinutes: productivity.pomodoro.durationMinutes)
        scheduleAlertAutoDismiss(after: 9)
        if mode.isExpanded {
            showToast("Focus session complete")
        }
        syncCollapsedMode()
    }

    func dismissActiveAlert() {
        alertAutoDismissTask?.cancel()
        activeAlert = nil
        syncCollapsedMode()
    }

    func restartPomodoroFromAlert() {
        alertAutoDismissTask?.cancel()
        activeAlert = nil
        productivity.resetPomodoro()
        productivity.togglePomodoro()
        syncCollapsedMode()
    }

    func joinMeetingFromAlert(_ url: URL) {
        calendar.openMeeting(url)
        dismissActiveAlert()
    }

    private func evaluateMeetingAlerts() {
        let currentNow = calendar.now
        var nextHeadsUp: MeetingHeadsUp?

        for event in calendar.upcomingEvents {
            guard let meetingURL = event.meetingURL,
                  let stage = CalendarLogic.meetingAlertStage(
                      now: currentNow,
                      startDate: event.startDate,
                      endDate: event.endDate
                  ) else {
                continue
            }

            switch stage {
            case .startingNow:
                if !triggeredStartingMeetingIDs.contains(event.id) {
                    triggeredStartingMeetingIDs.insert(event.id)
                    presentMeetingStartingAlert(event: event, url: meetingURL)
                }
            case .headsUp(let minutesRemaining):
                if case .meetingStarting(let activeEventId, _, _, _) = activeAlert, activeEventId == event.id {
                    continue
                }
                if nextHeadsUp == nil {
                    nextHeadsUp = MeetingHeadsUp(event: event, minutesRemaining: minutesRemaining)
                }
            }
        }

        if meetingHeadsUp != nextHeadsUp {
            meetingHeadsUp = nextHeadsUp
            syncCollapsedMode()
        }
    }

    private func presentMeetingStartingAlert(event: CalendarEventItem, url: URL) {
        if alertSoundsEnabled {
            NSSound(named: NSSound.Name("Ping"))?.play()
        }
        activeAlert = .meetingStarting(
            eventId: event.id,
            title: event.title,
            provider: event.meetingProvider ?? "Meeting",
            url: url
        )
        scheduleAlertAutoDismiss(after: 45)
        if mode.isExpanded {
            showToast("Starting now: \(event.title)")
        }
        syncCollapsedMode()
    }

    private func scheduleAlertAutoDismiss(after seconds: TimeInterval) {
        alertAutoDismissTask?.cancel()
        alertAutoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismissActiveAlert()
        }
    }

    func beginTextInput() {
        isEditingText = true
        hoverTask?.cancel()
        panel?.allowsKeyFocus = true
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func endTextInput() {
        isEditingText = false
        panel?.allowsKeyFocus = false
        if panel?.isKeyWindow == true {
            panel?.resignKey()
        }
    }

    func handleDragEntered() {
        isDragTargeted = true
        hoverTask?.cancel()
        if !mode.isExpanded || activeTab != .files {
            selectTab(.files)
        }
    }

    func handleDragExited() {
        isDragTargeted = false
    }

    func setHoveringCompactControls(_ hovering: Bool) {
        isHoveringCompactControls = hovering
        if hovering {
            hoverTask?.cancel()
        }
    }

    func handleHoverChanged(_ hovering: Bool) {
        guard hoverToExpandEnabled else { return }
        hoverTask?.cancel()

        if hovering {
            guard !mode.isExpanded && !mode.isAlert && !isHoveringCompactControls else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled, let self, !self.isHoveringCompactControls else { return }
                self.setMode(.expanded)
            }
        } else {
            guard mode.isExpanded, !isEditingText, !isDragTargeted, !isTrackingMenu, !isPresentingFilePicker else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled,
                      let self,
                      !self.isEditingText,
                      !self.isDragTargeted,
                      !self.isTrackingMenu,
                      !self.isPresentingFilePicker else { return }
                if let panel = self.panel, panel.frame.contains(NSEvent.mouseLocation) {
                    return
                }
                self.collapse()
            }
        }
    }

    // MARK: - Custom Notch Wallpaper

    private static var wallpaperStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("Floqy", isDirectory: true)
            .appendingPathComponent("notch-wallpaper.jpg")
    }

    func chooseWallpaperImage() {
        hoverTask?.cancel()
        isPresentingFilePicker = true
        NSApp.activate(ignoringOtherApps: true)

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.prompt = "Choose"
        openPanel.message = "Select an image to use as Floqy's notch wallpaper."

        openPanel.begin { [weak self] response in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.isPresentingFilePicker = false }
                guard response == .OK,
                      let selectedURL = openPanel.url,
                      let sourceImage = NSImage(contentsOf: selectedURL),
                      let prepared = Self.resizeWallpaperImage(sourceImage) else {
                    return
                }

                let targetURL = Self.wallpaperStorageURL
                try? FileManager.default.createDirectory(
                    at: targetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? prepared.jpegData.write(to: targetURL, options: .atomic)

                self.wallpaperImage = prepared.image
                if !self.themePreset.usesWallpaper {
                    self.themePreset = .wallpaperDark
                }
                self.showToast("Notch wallpaper updated")
            }
        }
    }

    func clearWallpaperImage() {
        try? FileManager.default.removeItem(at: Self.wallpaperStorageURL)
        wallpaperImage = nil
        if themePreset == .wallpaperDark {
            themePreset = .obsidian
        } else if themePreset == .wallpaperLight {
            themePreset = .pureWhite
        }
        showToast("Notch wallpaper cleared")
    }

    private static func resizeWallpaperImage(
        _ image: NSImage,
        maxDimension: CGFloat = 1280
    ) -> (image: NSImage, jpegData: Data)? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        let srcSize = CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        guard srcSize.width > 0, srcSize.height > 0 else { return nil }
        let longest = max(srcSize.width, srcSize.height)
        let scale = longest > maxDimension ? (maxDimension / longest) : 1.0
        let targetSize = CGSize(
            width: max(1, floor(srcSize.width * scale)),
            height: max(1, floor(srcSize.height * scale))
        )

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        bitmap.draw(in: NSRect(origin: .zero, size: targetSize))
        NSGraphicsContext.restoreGraphicsState()

        guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.86]),
              let finalImage = NSImage(data: jpegData) else { return nil }
        return (finalImage, jpegData)
    }

    // MARK: - Phase 2 Files Tray Staging

    func stageDroppedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        filesTray.stageFiles(urls)
        selectTab(.files)
        showToast(urls.count == 1 ? "Staged \(urls[0].lastPathComponent)" : "Staged \(urls.count) files")
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

        let initialFrame = geometry.panelFrame(
            for: mode,
            homeSubView: homeSubView,
            activeTab: activeTab,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        )
        let notchPanel = NotchPanel(contentRect: initialFrame)
        notchPanel.onCancel = { [weak self] in
            self?.collapse()
        }

        let container = NotchPassthroughContainerView(
            rootView: NotchRootView(manager: self),
            frame: CGRect(origin: .zero, size: initialFrame.size),
            activeHitRectProvider: { [weak self] size in
                guard let self else { return .zero }
                return self.geometry.hitRectInPanel(
                    for: self.mode,
                    homeSubView: self.homeSubView,
                    activeTab: self.activeTab,
                    idleAppearance: self.idleAppearance,
                    idleWidth: self.idleWidth,
                    in: size
                )
            }
        )
        container.onHoverChanged = { [weak self] hovering in
            self?.handleHoverChanged(hovering)
        }
        container.onDragEntered = { [weak self] in
            self?.handleDragEntered()
        }
        container.onDragExited = { [weak self] in
            self?.handleDragExited()
        }
        container.onFilesDropped = { [weak self] urls in
            self?.stageDroppedFiles(urls)
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
        panel?.allowsKeyFocus = isEditingText
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
                self.relocateToPreferredScreen()
                self.syncCursorScreenMonitor()
            }
        }
    }

    // MARK: - Launch at Login (SMAppService)

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = (status == .enabled)
        launchAtLoginNeedsApproval = (status == .requiresApproval)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func relocateToPreferredScreen() {
        refreshGeometry()
        let effectiveSubView: HomeSubView = (mode.isExpanded && isShowingInlineSettings) ? .overview : homeSubView
        let updated = geometry.panelFrame(
            for: mode,
            homeSubView: effectiveSubView,
            activeTab: activeTab,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        )
        resizePanelAtomically(to: updated)
        updateTrackingRect?()
    }

    private func syncCursorScreenMonitor() {
        if let cursorScreenMonitor {
            NSEvent.removeMonitor(cursorScreenMonitor)
            self.cursorScreenMonitor = nil
        }
        guard displayPreference == .followCursor, NSScreen.screens.count > 1 else { return }
        cursorScreenMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let now = CACurrentMediaTime()
                guard now - self.lastCursorScreenCheck >= 0.35 else { return }
                self.lastCursorScreenCheck = now
                guard !self.mode.isExpanded, !self.mode.isAlert else { return }
                let candidate = NotchGeometry(screen: NotchGeometry.preferredScreen(for: .followCursor))
                if candidate.screenFrame != self.geometry.screenFrame {
                    self.relocateToPreferredScreen()
                }
            }
        }
    }

    private func observeMenuTracking() {
        menuBeginObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTrackingMenu = true
                self?.hoverTask?.cancel()
            }
        }
        menuEndObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTrackingMenu = false
            }
        }
    }

    private func refreshGeometry() {
        geometry = NotchGeometry(screen: NotchGeometry.preferredScreen(for: displayPreference))
    }

    // MARK: - Global Shortcuts (Cmd+Shift+Space & Cmd+Shift+V)

    private func registerGlobalHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let manager = Unmanaged<NotchManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    if hotKeyID.id == 2 {
                        if manager.mode.isExpanded && manager.activeTab == .clipboard {
                            manager.collapse()
                        } else {
                            manager.selectTab(.clipboard)
                        }
                    } else {
                        manager.toggleExpanded()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard status == noErr else { return }

        let signature = OSType(0x464C_5159) // 'FLQY'
        let toggleID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            toggleID,
            GetApplicationEventTarget(),
            0,
            &toggleHotKeyRef
        )

        let clipboardID = EventHotKeyID(signature: signature, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            clipboardID,
            GetApplicationEventTarget(),
            0,
            &clipboardHotKeyRef
        )
    }
}
