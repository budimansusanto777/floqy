import AppKit
import EventKit
import SwiftUI

/// Settings window for notch behavior, EventKit calendar sync, Obsidian vault, focus timer, and hardware diagnostics.
struct SettingsView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject private var calendar: CalendarService
    @ObservedObject private var obsidian: ObsidianService
    @ObservedObject private var productivity: ProductivityService
    @ObservedObject private var ai: AIService

    @State private var recordingAction: ShortcutAction?
    @State private var shortcutFeedback: String?
    @State private var hookFeedback: String?
    @State private var keyMonitor: Any?

    init(manager: NotchManager) {
        self.manager = manager
        self.calendar = manager.calendar
        self.obsidian = manager.obsidian
        self.productivity = manager.productivity
        self.ai = manager.ai
    }

    var body: some View {
        Form {
            Section("Notch Behavior") {
                Picker("Theme", selection: $manager.themePreset) {
                    ForEach(NotchThemePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                Picker("Idle notch", selection: $manager.idleAppearance) {
                    ForEach(IdleAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                Picker("Idle width", selection: $manager.idleWidth) {
                    ForEach(IdleNotchWidth.allCases) { width in
                        Text(width.title).tag(width)
                    }
                }
                .disabled(!manager.idleAppearance.usesBottomChin)
                Toggle("Headphones connected card", isOn: $manager.headphonesCardEnabled)
                Toggle("Charging status card", isOn: $manager.chargingCardEnabled)
                Toggle("Low battery alerts", isOn: $manager.lowBatteryAlertsEnabled)
                Toggle("Auto-expand on hover", isOn: $manager.hoverToExpandEnabled)
                Toggle("Notification sounds", isOn: $manager.alertSoundsEnabled)
                Toggle("Start Floqy at login", isOn: Binding(
                    get: { manager.launchAtLoginEnabled },
                    set: { manager.setLaunchAtLogin($0) }
                ))
                if manager.launchAtLoginNeedsApproval {
                    HStack {
                        Text("Requires approval in Login Items.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") {
                            manager.openLoginItemsSettings()
                        }
                    }
                }
                if let loginError = manager.launchAtLoginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Keyboard Shortcuts") {
                ForEach(ShortcutAction.allCases) { action in
                    ShortcutRecorderRow(
                        action: action,
                        binding: manager.shortcutBindings[action],
                        isRecording: recordingAction == action,
                        onToggleRecord: {
                            toggleShortcutRecording(for: action)
                        }
                    )
                }

                if let shortcutFeedback {
                    Text(shortcutFeedback)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Click a shortcut and press a new key combination. Esc cancels, Delete clears.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Reset Defaults") {
                        stopShortcutRecording()
                        shortcutFeedback = nil
                        manager.resetShortcutsToDefaults()
                    }
                }
            }

            Section("Calendar") {
                HStack {
                    LabeledContent("Permission") {
                        Text(eventKitStatusLabel)
                            .foregroundStyle(calendar.authorizationStatus == .fullAccess ? .green : .secondary)
                    }
                    Spacer()
                    if calendar.authorizationStatus == .fullAccess {
                        Button("Refresh") {
                            calendar.refreshEvents()
                        }
                    } else if calendar.authorizationStatus == .notDetermined {
                        Button("Connect") {
                            calendar.requestAccess()
                        }
                    } else if calendar.authorizationStatus == .denied || calendar.authorizationStatus == .restricted {
                        Button("Open Privacy Settings") {
                            calendar.openCalendarPrivacySettings()
                        }
                    }
                }

                if calendar.authorizationStatus == .fullAccess && calendar.syncedCalendarCount > 0 {
                    Text("Calendars: \(calendar.syncedCalendarNames.prefix(4).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("Syncs Google, iCloud, and Microsoft Exchange/Teams calendars enabled in System Settings → Internet Accounts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Notes") {
                HStack {
                    LabeledContent("Notes Folder") {
                        Text(obsidian.vaultName ?? "Local (Default)")
                            .foregroundStyle(obsidian.isVaultConfigured ? .green : .secondary)
                    }
                    Spacer()
                    Button(obsidian.isVaultConfigured ? "Change…" : "Choose Folder…") {
                        obsidian.chooseVaultFolder()
                    }
                    if obsidian.isVaultConfigured {
                        Button("Use Default", role: .destructive) {
                            obsidian.disconnectVault()
                        }
                    }
                    Button("Open Folder") {
                        obsidian.openActiveNotesFolder()
                    }
                }

                Text("Saves Markdown notes locally by default, or to any custom folder (including an Obsidian Vault).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Focus Timer") {
                Stepper(
                    value: Binding(
                        get: { productivity.pomodoro.durationMinutes },
                        set: { productivity.setPomodoroDuration(minutes: $0) }
                    ),
                    in: PomodoroState.minDurationMinutes...PomodoroState.maxDurationMinutes
                ) {
                    LabeledContent("Duration") {
                        Text("\(productivity.pomodoro.durationMinutes) min")
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Toggle("Show paused timer in notch", isOn: $manager.showPausedPomodoroInNotch)
            }

            Section("System") {
                Toggle("Alert when RAM exceeds \(SystemLogic.ramAlertThresholdPercent)%", isOn: $manager.ramAlertEnabled)
            }

            Section("AI Agents & Hooks") {
                ForEach(AIAgentKind.allCases) { agent in
                    let isConnected = ai.hookStatus[agent] == true
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.displayName)
                            Text(agent.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if agent.supportsHook {
                            Button(isConnected ? "Connected" : "Connect") {
                                hookFeedback = ai.toggleHook(for: agent)
                            }
                            .foregroundStyle(isConnected ? .green : .accentColor)
                        }

                        Button("Open") {
                            ai.openAgentApp(agent)
                        }
                    }
                }

                if let hookFeedback {
                    Text(hookFeedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Display Geometry") {
                Picker("Display", selection: $manager.displayPreference) {
                    ForEach(DisplayPreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                }
                LabeledContent("Hardware Notch") {
                    Text(manager.geometry.hasHardwareNotch ? "Detected" : "Fallback Mode")
                        .foregroundStyle(manager.geometry.hasHardwareNotch ? .green : .secondary)
                }
                LabeledContent("Notch Frame") {
                    let size = manager.geometry.hardwareNotchSize
                    Text("\(Int(size.width)) × \(Int(size.height)) pt")
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("About Floqy") {
                LabeledContent("Version", value: UpdateLogic.currentAppVersion())
                LabeledContent("Software Update") {
                    HStack(spacing: 8) {
                        Button(manager.updateStatus == .checking ? "Checking…" : "Check for Updates") {
                            manager.checkForUpdates(presentAlert: false)
                        }
                        .disabled(manager.updateStatus.isBusy)

                        if case .updateAvailable(let release) = manager.updateStatus {
                            if manager.canSelfInstallUpdate, release.dmgURL != nil, release.dmgSHA256 != nil {
                                Button("Install & Relaunch") {
                                    manager.installAvailableUpdate()
                                }
                                .buttonStyle(.borderedProminent)

                                Button("DMG") {
                                    manager.openUpdateDownload()
                                }
                            } else {
                                Button("Download") {
                                    manager.openUpdateDownload()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                switch manager.updateStatus {
                case .updateAvailable(let release):
                    Text("Floqy v\(release.version) is available on GitHub.")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .installing(let progress, let stage):
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress)
                        Text(stage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .upToDate(let latestVersion):
                    Text("You are up to date (v\(latestVersion)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    HStack {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Releases") {
                            manager.openUpdateDownload()
                        }
                    }
                case .idle, .checking:
                    EmptyView()
                }
                LabeledContent("License", value: "GNU GPLv3")
                LabeledContent("Copyright", value: "© 2026 budimansusanto777")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 550)
        .onAppear {
            ai.refreshHookStatus()
        }
        .onDisappear {
            stopShortcutRecording()
        }
    }

    private func toggleShortcutRecording(for action: ShortcutAction) {
        if recordingAction == action {
            stopShortcutRecording()
            return
        }
        stopShortcutRecording()
        recordingAction = action
        shortcutFeedback = nil
        manager.setHotKeysSuspended(true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = UInt32(event.keyCode)
            if code == 53 { // Escape
                stopShortcutRecording()
                return nil
            }
            if code == 51 || code == 117 { // Delete / Forward Delete
                manager.setShortcut(nil, for: action)
                shortcutFeedback = nil
                stopShortcutRecording()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var carbonMods: UInt32 = 0
            if flags.contains(.command) { carbonMods |= GlobalShortcut.cmdMask }
            if flags.contains(.shift) { carbonMods |= GlobalShortcut.shiftMask }
            if flags.contains(.option) { carbonMods |= GlobalShortcut.optionMask }
            if flags.contains(.control) { carbonMods |= GlobalShortcut.controlMask }

            let candidate = GlobalShortcut(keyCode: code, carbonModifiers: carbonMods)
            if let error = manager.setShortcut(candidate, for: action) {
                shortcutFeedback = error
            } else {
                shortcutFeedback = nil
                stopShortcutRecording()
            }
            return nil
        }
    }

    private func stopShortcutRecording() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        recordingAction = nil
        manager.setHotKeysSuspended(false)
    }

    private var eventKitStatusLabel: String {
        switch calendar.authorizationStatus {
        case .fullAccess:
            return "Authorized (\(calendar.syncedCalendarCount) calendars)"
        case .notDetermined:
            return "Not Requested"
        case .denied, .restricted:
            return "Denied"
        default:
            return "Unavailable"
        }
    }
}

private struct ShortcutRecorderRow: View {
    let action: ShortcutAction
    let binding: GlobalShortcut?
    let isRecording: Bool
    let onToggleRecord: () -> Void

    var body: some View {
        LabeledContent(action.title) {
            Button(action: onToggleRecord) {
                Text(isRecording ? "Press keys…" : (binding?.displayString ?? "Not Set"))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRecording ? .white : (binding != nil ? .primary : .secondary))
                    .frame(minWidth: 96)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.accentColor : Color.secondary.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
