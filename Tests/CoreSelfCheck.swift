import CoreGraphics
import Foundation

@main
enum CoreSelfCheck {
    static func main() {
        checkNotchedScreenDetection()
        checkNonNotchedAndNilScreenFallbacks()
        checkPanelFramesMatchModes()
        checkHitRectsContainedAndOrderedByMode()
        checkNotchShellShapeGeneratesNonEmptyPaths()
        checkSixTabsAreSymmetrical()
        checkDailyFlowLogic()
        checkMonthGridLogic()
        checkProductivityToolsLogic()
        print("CoreSelfCheck: 9/9 checks passed.")
    }

    private static func checkNotchedScreenDetection() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let leftAux = CGRect(x: 0, y: 944, width: 656, height: 38)
        let rightAux = CGRect(x: 856, y: 944, width: 656, height: 38)

        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftAux,
            auxiliaryTopRightArea: rightAux
        )

        precondition(geometry.hasHardwareNotch, "Expected hardware notch to be detected")
        precondition(geometry.hardwareNotchSize.width == 200, "Unexpected notch width")
        precondition(geometry.hardwareNotchSize.height == 38, "Unexpected notch height")
        precondition(geometry.shellSize(for: .idle) == CGSize(width: 200, height: 38), "Idle size mismatch")
        precondition(geometry.notchSafeTopHeight == 38, "Safe top height should match hardware notch height")
        precondition(geometry.notchCenterGapWidth > geometry.hardwareNotchSize.width, "Center gap must clear hardware notch")
        precondition(geometry.shellSize(for: .compact(.music)).width > geometry.notchCenterGapWidth + 160, "Compact wings must clear hardware camera")
    }

    private static func checkNonNotchedAndNilScreenFallbacks() {
        let externalFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let externalGeometry = NotchGeometry(
            screenFrame: externalFrame,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        precondition(!externalGeometry.hasHardwareNotch, "External display should not report hardware notch")
        precondition(externalGeometry.hardwareNotchSize == CGSize(width: 196, height: 32), "External fallback mismatch")
        precondition(externalGeometry.shellSize(for: .idle) == CGSize(width: 196, height: 32), "Idle fallback mismatch")
        precondition(externalGeometry.notchSafeTopHeight == 24, "Fallback safe top height mismatch")

        let nilGeometry = NotchGeometry(screen: nil)
        precondition(!nilGeometry.hasHardwareNotch, "Nil screen should not report hardware notch")
        precondition(nilGeometry.screenFrame == NotchGeometry.fallbackScreenFrame, "Nil screen frame mismatch")
    }

    private static func checkPanelFramesMatchModes() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let leftAux = CGRect(x: 0, y: 944, width: 656, height: 38)
        let rightAux = CGRect(x: 856, y: 944, width: 656, height: 38)
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftAux,
            auxiliaryTopRightArea: rightAux
        )

        let idleFrame = geometry.panelFrame(for: .idle)
        precondition(idleFrame.size == CGSize(width: 200, height: 38), "Idle panel frame must match hardware notch exactly")
        precondition(abs(idleFrame.maxY - screenFrame.maxY) <= 0.5, "Idle panel must anchor to screen top")
        precondition(abs(idleFrame.midX - screenFrame.midX) <= 0.5, "Idle panel must center horizontally")

        let compactFrame = geometry.panelFrame(for: .compact(.music))
        precondition(compactFrame.height <= geometry.hardwareNotchSize.height + 12, "Compact panel height must stay tight")
        precondition(abs(compactFrame.maxY - screenFrame.maxY) <= 0.5, "Compact panel must anchor to screen top")

        let expandedOverview = geometry.panelFrame(for: .expanded, homeSubView: .overview, activeTab: .home)
        precondition(expandedOverview == geometry.panelCanvasFrame(), "Expanded overview frame must equal panelCanvasFrame")
        precondition(expandedOverview.width == 560 + NotchGeometry.horizontalPadding, "Expanded panel width mismatch")

        let expandedCalendar = geometry.panelFrame(for: .expanded, homeSubView: .calendar, activeTab: .home)
        precondition(expandedCalendar.height > expandedOverview.height, "Calendar mode height must exceed Overview height")
        let filesWhileCalendar = geometry.panelFrame(for: .expanded, homeSubView: .calendar, activeTab: .files)
        precondition(filesWhileCalendar.height == expandedOverview.height, "Non-Home tabs must stay at Overview height")
    }

    private static func checkHitRectsContainedAndOrderedByMode() {
        let geometry = NotchGeometry(screen: nil)
        let canvasBounds = CGRect(origin: .zero, size: geometry.panelCanvasFrame().size)

        let idleOwnFrame = CGRect(origin: .zero, size: geometry.panelFrame(for: .idle).size)
        let idleHitOwn = geometry.hitRectInPanel(for: .idle)
        precondition(idleOwnFrame.contains(idleHitOwn), "Idle hit rect must fit inside idle panel frame")

        let idleHit = geometry.hitRectInPanel(for: .idle, in: canvasBounds.size)
        let compactHit = geometry.hitRectInPanel(for: .compact(.music), in: canvasBounds.size)
        let expandedHit = geometry.hitRectInPanel(for: .expanded, in: canvasBounds.size)

        precondition(canvasBounds.contains(idleHit), "Idle hit rect outside canvas")
        precondition(canvasBounds.contains(compactHit), "Compact hit rect outside canvas")
        precondition(canvasBounds.contains(expandedHit), "Expanded hit rect outside canvas")

        precondition(idleHit.width < compactHit.width, "Idle hit width should be smaller than compact")
        precondition(compactHit.width < expandedHit.width, "Compact hit width should be smaller than expanded")
        precondition(idleHit.maxY == canvasBounds.height, "Idle hit rect should touch top of panel")
        precondition(compactHit.maxY == canvasBounds.height, "Compact hit rect should touch top of panel")
        precondition(expandedHit.maxY == canvasBounds.height, "Expanded hit rect should touch top of panel")
    }

    private static func checkNotchShellShapeGeneratesNonEmptyPaths() {
        let geometry = NotchGeometry(screen: nil)
        for mode in [NotchMode.idle, .compact(.music), .expanded] {
            let size = geometry.shellSize(for: mode)
            let rect = CGRect(
                x: 0,
                y: 0,
                width: size.width + geometry.earPadding(for: mode),
                height: size.height
            )
            let path = NotchShellShape(
                topEarRadius: mode == .idle ? 0 : NotchGeometry.earWidth,
                bottomCornerRadius: geometry.bottomRadius(for: mode)
            ).path(in: rect)
            precondition(!path.isEmpty, "NotchShellShape path should not be empty")
        }
    }

    private static func checkSixTabsAreSymmetrical() {
        precondition(NotchTab.leftTabs.count == 3, "Expected 3 left tabs")
        precondition(NotchTab.rightTabs.count == 3, "Expected 3 right tabs")
        precondition(Set(NotchTab.leftTabs + NotchTab.rightTabs) == Set(NotchTab.allCases), "Tabs must cover all cases")
    }

    private static func checkDailyFlowLogic() {
        let meetURL = CalendarLogic.extractMeetingURL(from: [
            nil,
            "Join here: https://meet.google.com/abc-defg-hij.",
            "https://example.com/ignored"
        ])
        precondition(meetURL?.absoluteString == "https://meet.google.com/abc-defg-hij", "Failed to extract Google Meet URL")

        let zoomURL = CalendarLogic.extractMeetingURL(from: ["https://us02web.zoom.us/j/123456789?pwd=xyz"])
        precondition(zoomURL?.host == "us02web.zoom.us", "Failed to extract Zoom URL")

        let ignoredURL = CalendarLogic.extractMeetingURL(from: ["https://github.com/budimansusanto777/floqy"])
        precondition(ignoredURL == nil, "Non-meeting URL should be ignored")

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        precondition(
            CalendarLogic.formatCountdown(from: now, to: now.addingTimeInterval(-60), end: now.addingTimeInterval(600)) == "Now",
            "Active meeting should show Now"
        )
        precondition(
            CalendarLogic.formatCountdown(from: now, to: now.addingTimeInterval(12 * 60), end: now.addingTimeInterval(42 * 60)) == "In 12 min",
            "12-minute countdown mismatch"
        )
        precondition(
            CalendarLogic.formatCountdown(from: now, to: now.addingTimeInterval(90 * 60), end: now.addingTimeInterval(120 * 60)) == "In 1h 30m",
            "Hour/minute countdown mismatch"
        )

        var pomo = PomodoroState(remainingSeconds: 2, isRunning: true)
        precondition(pomo.formattedTime == "00:02", "Pomodoro time formatting mismatch")
        precondition(!pomo.tick() && pomo.remainingSeconds == 1 && pomo.isRunning, "First tick should decrement")
        precondition(pomo.tick() && pomo.remainingSeconds == 0 && !pomo.isRunning, "Second tick should complete")
        pomo.reset()
        precondition(pomo.remainingSeconds == PomodoroState.defaultDuration && !pomo.isRunning, "Reset mismatch")

        pomo.setDuration(minutes: 0)
        precondition(pomo.durationMinutes == 1 && pomo.formattedTime == "01:00", "Min duration clamp mismatch")
        pomo.setDuration(minutes: 999)
        precondition(pomo.durationMinutes == 120 && pomo.formattedTime == "120:00", "Max duration clamp mismatch")
        pomo.setDuration(minutes: 45)
        precondition(pomo.durationMinutes == 45 && pomo.formattedTime == "45:00", "45m preset mismatch")
        _ = pomo.tick()
        pomo.reset()
        precondition(pomo.remainingSeconds == 45 * 60 && !pomo.isRunning, "Reset must restore configured duration")

        precondition(NowPlayingTrack.formatDuration(88) == "1:28", "Duration format mismatch")
        precondition(NowPlayingTrack.formatDuration(-5) == "0:00", "Negative duration format mismatch")

        let sample = [TodoItem(title: "Ship Phase 1", isDone: false)]
        let encoded = try? JSONEncoder().encode(sample)
        let decoded = encoded.flatMap { try? JSONDecoder().decode([TodoItem].self, from: $0) }
        precondition(decoded == sample, "TodoItem JSON round-trip mismatch")
    }

    private static func checkMonthGridLogic() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let augAnchor = cal.date(from: DateComponents(year: 2026, month: 8, day: 15))!
        let augBounds = CalendarLogic.monthBounds(for: augAnchor, calendar: cal)
        let augCells = CalendarLogic.monthGridCells(for: augAnchor, calendar: cal)
        precondition(CalendarLogic.dayKey(for: augBounds.start, calendar: cal) == "2026-08-01", "Month start mismatch")
        precondition(CalendarLogic.dayKey(for: augBounds.end, calendar: cal) == "2026-09-01", "Month end mismatch")
        precondition(augCells.count == 37, "August 2026 grid should have 6 leading blanks + 31 days")
        precondition(augCells.prefix(6).allSatisfy { $0.date == nil }, "First 6 cells must be blank")
        precondition(augCells.last?.dayNumber == 31, "Last day should be 31")
    }

    private static func checkProductivityToolsLogic() {
        // File classification & formatting
        precondition(StagedFileItem.classify(pathExtension: "heic") == .image, "HEIC should classify as image")
        precondition(StagedFileItem.classify(pathExtension: "PDF") == .pdf, "PDF classification mismatch")
        precondition(StagedFileItem.classify(pathExtension: "swift") == .code, "Swift should classify as code")
        precondition(StagedFileItem.formatByteCount(840 * 1024) == "840 KB", "KB formatting mismatch")
        precondition(StagedFileItem.formatByteCount(2_516_582) == "2.4 MB", "MB formatting mismatch")

        // Obsidian path & entry formatting
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 9, minute: 5))!
        precondition(
            ObsidianLogic.resolveRelativePath(for: .quickIdeas, date: refDate) == "Inbox/Quick-Ideas.md",
            "Quick Ideas path mismatch"
        )
        let entry = ObsidianLogic.formatMarkdownEntry(
            body: "Test note #floqy",
            tags: ["#floqy", "idea", "#IDEA"],
            timestamp: refDate
        )
        precondition(entry.hasSuffix("Test note #floqy #idea\n"), "Obsidian entry deduplication mismatch: \(entry)")

        let vault = URL(fileURLWithPath: "/tmp/MyVault")
        precondition(ObsidianLogic.safeTargetURL(vaultURL: vault, relativePath: "Daily/2026-11-25.md") != nil, "Valid vault path rejected")
        precondition(ObsidianLogic.safeTargetURL(vaultURL: vault, relativePath: "../../etc/passwd") == nil, "Path traversal must be blocked")

        // Clipboard classification & filtering
        precondition(ClipboardLogic.classifyText("https://github.com/budimansusanto777/floqy") == .url, "URL classification failed")
        precondition(ClipboardLogic.classifyText("func hello() { return }") == .code, "Code classification failed")
        precondition(ClipboardLogic.classifyText("Plain reminder note") == .text, "Plain text classification failed")

        let older = ClipboardEntry(kind: .text, textContent: "alpha note", isPinned: false, createdAt: refDate)
        let pinned = ClipboardEntry(kind: .url, textContent: "https://example.com", isPinned: true, createdAt: refDate.addingTimeInterval(-100))
        let newer = ClipboardEntry(kind: .code, textContent: "let alpha = 1", isPinned: false, createdAt: refDate.addingTimeInterval(60))

        let sortedAll = ClipboardLogic.filterAndSort([older, pinned, newer], query: "")
        precondition(sortedAll.map(\.id) == [pinned.id, newer.id, older.id], "Pinned must sort first, then newest")

        let filtered = ClipboardLogic.filterAndSort([older, pinned, newer], query: "alpha")
        precondition(filtered.map(\.id) == [newer.id, older.id], "Search filter mismatch")
    }
}
