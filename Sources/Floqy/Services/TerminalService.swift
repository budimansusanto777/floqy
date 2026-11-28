import AppKit
import Combine
import Foundation

/// Lists open macOS Terminal.app windows/tabs, renames custom titles, and focuses or opens Terminal windows on demand.
@MainActor
final class TerminalService: ObservableObject {
    @Published private(set) var sessions: [TerminalSessionItem] = []
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var permissionDenied: Bool = false

    private static let terminalBundleID = "com.apple.Terminal"

    func refresh() {
        guard !isRefreshing else { return }

        // Avoid launching Terminal.app if it is not currently open.
        if NSRunningApplication.runningApplications(withBundleIdentifier: Self.terminalBundleID).isEmpty {
            sessions = []
            permissionDenied = false
            return
        }

        isRefreshing = true
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.runAppleScript(Self.snapshotScript)
            }.value

            guard let self else { return }
            self.isRefreshing = false
            if result.permissionDenied {
                self.permissionDenied = true
                self.sessions = []
            } else {
                self.permissionDenied = false
                self.sessions = TerminalSessionLogic.parseTerminalSnapshot(result.output ?? "")
            }
        }
    }

    func focus(_ session: TerminalSessionItem) {
        let tty = TerminalSessionLogic.escapeAppleScriptString(session.tty)
        let script = """
        tell application "Terminal"
            set matchedWindow to missing value
            set matchedTab to missing value
            if "\(tty)" is not "" then
                repeat with w in windows
                    try
                        repeat with t in tabs of w
                            if tty of t is "\(tty)" then
                                set matchedWindow to w
                                set matchedTab to t
                                exit repeat
                            end if
                        end repeat
                    end try
                    if matchedTab is not missing value then exit repeat
                end repeat
            end if
            if matchedTab is missing value then
                try
                    set matchedWindow to window id \(session.windowID)
                    set matchedTab to tab \(session.tabIndex) of matchedWindow
                end try
            end if
            if matchedWindow is not missing value and matchedTab is not missing value then
                set selected of matchedTab to true
                set index of matchedWindow to 1
            end if
            activate
        end tell
        """

        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.runAppleScript(script)
            }.value
            guard let self, result.permissionDenied else { return }
            self.permissionDenied = true
        }
    }

    func rename(_ session: TerminalSessionItem, to newName: String) async -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let tty = TerminalSessionLogic.escapeAppleScriptString(session.tty)
        let escapedName = TerminalSessionLogic.escapeAppleScriptString(trimmed)
        let script = """
        tell application "Terminal"
            set matchedTab to missing value
            if "\(tty)" is not "" then
                repeat with w in windows
                    try
                        repeat with t in tabs of w
                            if tty of t is "\(tty)" then
                                set matchedTab to t
                                exit repeat
                            end if
                        end repeat
                    end try
                    if matchedTab is not missing value then exit repeat
                end repeat
            end if
            if matchedTab is missing value then
                try
                    set matchedTab to tab \(session.tabIndex) of window id \(session.windowID)
                end try
            end if
            if matchedTab is not missing value then
                set custom title of matchedTab to "\(escapedName)"
                set title displays custom title of matchedTab to true
                return "1"
            end if
        end tell
        return "0"
        """

        let result = await Task.detached(priority: .userInitiated) {
            Self.runAppleScript(script)
        }.value

        if result.permissionDenied {
            permissionDenied = true
            return false
        }

        let didRename = result.output == "1"
        if didRename {
            refresh()
        }
        return didRename
    }

    func createNewWindow() {
        let script = """
        tell application "Terminal"
            do script ""
            activate
        end tell
        """

        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.runAppleScript(script)
            }.value
            guard let self else { return }
            if result.permissionDenied {
                self.permissionDenied = true
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self.refresh()
        }
    }

    func openAutomationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - AppleScript

    private nonisolated static let snapshotScript = """
    set outText to ""
    set fieldSep to ASCII character 31
    set rowSep to ASCII character 30
    tell application "Terminal"
        repeat with w in windows
            try
                set wid to id of w
                set wname to name of w
                set tabCount to count of tabs of w
                repeat with i from 1 to tabCount
                    set t to tab i of w
                    set ttyPath to ""
                    try
                        set ttyPath to tty of t
                    end try
                    set customTitleText to ""
                    try
                        if title displays custom title of t then
                            set customTitleText to custom title of t
                        end if
                    end try
                    set isBusyVal to "0"
                    try
                        if busy of t then set isBusyVal to "1"
                    end try
                    set procCSV to ""
                    set oldDelims to AppleScript's text item delimiters
                    try
                        set AppleScript's text item delimiters to ","
                        set procCSV to (processes of t) as string
                    end try
                    set AppleScript's text item delimiters to oldDelims
                    set rowText to (wid as string) & fieldSep & (i as string) & fieldSep & ttyPath & fieldSep & customTitleText & fieldSep & wname & fieldSep & isBusyVal & fieldSep & procCSV
                    if outText is "" then
                        set outText to rowText
                    else
                        set outText to outText & rowSep & rowText
                    end if
                end repeat
            end try
        end repeat
    end tell
    return outText
    """

    private nonisolated static func runAppleScript(_ source: String) -> (output: String?, permissionDenied: Bool) {
        guard let script = NSAppleScript(source: source) else {
            return (nil, false)
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            let errorCode = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            return (nil, errorCode == -1743)
        }
        return (descriptor.stringValue ?? "", false)
    }
}
