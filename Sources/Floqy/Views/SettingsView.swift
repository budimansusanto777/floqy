import EventKit
import SwiftUI

/// Settings window for notch behavior, EventKit calendar sync, focus timer, and hardware diagnostics.
struct SettingsView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject private var calendar: CalendarService
    @ObservedObject private var productivity: ProductivityService

    init(manager: NotchManager) {
        self.manager = manager
        self.calendar = manager.calendar
        self.productivity = manager.productivity
    }

    var body: some View {
        Form {
            Section("Notch Behavior") {
                Toggle("Auto-expand on hover", isOn: $manager.hoverToExpandEnabled)

                LabeledContent("Global Shortcut") {
                    Text("⌘ ⇧ Space")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
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
            }

            Section("Display Geometry") {
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
                LabeledContent("Version", value: "0.1.0 (Phase 1)")
                LabeledContent("License", value: "GNU GPLv3")
                LabeledContent("Copyright", value: "© 2026 budimansusanto777")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 390)
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
