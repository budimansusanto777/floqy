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
        checkNotchEnhancementsLogic()
        checkSystemLogic()
        print("CoreSelfCheck: 11/11 checks passed.")
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

    private static func checkNotchEnhancementsLogic() {
        let geometry = NotchGeometry(screen: nil)
        let alert = NotchAlert.pomodoroComplete(durationMinutes: 25)
        let compactSize = geometry.shellSize(for: .compact(.pomodoro))
        let alertSize = geometry.shellSize(for: .alert(alert))
        let alertFrame = geometry.panelFrame(for: .alert(alert))
        let alertHit = geometry.hitRectInPanel(for: .alert(alert))
        precondition(alertSize.height > compactSize.height, "Alert shell must expand vertically beyond compact height")
        precondition(CGRect(origin: .zero, size: alertFrame.size).contains(alertHit), "Alert hit rect must fit inside alert panel")

        var shape = NotchShellShape(topEarRadius: 12, bottomCornerRadius: 22)
        shape.animatableData = .init(6, 18)
        precondition(shape.topEarRadius == 6 && shape.bottomCornerRadius == 18, "NotchShellShape AnimatablePair mismatch")
        let clampedPath = NotchShellShape(topEarRadius: -2, bottomCornerRadius: -4).path(in: CGRect(x: 0, y: 0, width: 200, height: 38))
        precondition(!clampedPath.isEmpty, "NotchShellShape must clamp negative radii safely")

        var pomo = PomodoroState(durationMinutes: 2)
        precondition(!pomo.isPaused && pomo.remainingProgress == 1.0, "Fresh Pomodoro must not report paused")
        pomo.toggleForCheck()
        _ = pomo.tick()
        pomo.isRunning = false
        precondition(pomo.isPaused, "Stopped mid-session Pomodoro must report paused")
        precondition(pomo.remainingProgress > 0.9 && pomo.remainingProgress < 1.0, "Remaining progress mismatch")

        let teamsMeet = CalendarLogic.extractMeetingURL(from: ["https://teams.microsoft.com/meet/123456"])
        precondition(teamsMeet != nil && CalendarLogic.meetingProvider(for: teamsMeet!) == "Teams", "Teams /meet/ URL parsing failed")

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let end = now.addingTimeInterval(3600)
        precondition(CalendarLogic.meetingAlertStage(now: now, startDate: now.addingTimeInterval(360), endDate: end) == nil, "6m ahead must not trigger")
        precondition(CalendarLogic.meetingAlertStage(now: now, startDate: now.addingTimeInterval(250), endDate: end) == .headsUp(minutesRemaining: 5), "5m heads-up mismatch")
        precondition(CalendarLogic.meetingAlertStage(now: now, startDate: now.addingTimeInterval(-30), endDate: end) == .startingNow, "Starting now mismatch")
        precondition(CalendarLogic.meetingAlertStage(now: now, startDate: now.addingTimeInterval(-180), endDate: end) == nil, "After 2m start window must stop triggering")

        let resolvedAlert = NotchMode.resolvedCollapsedMode(
            activeAlert: alert,
            hasMeetingHeadsUp: true,
            pomodoroRunning: true,
            pomodoroPaused: false,
            showPausedPomodoroInNotch: true,
            isMusicPlaying: true
        )
        precondition(resolvedAlert == .alert(alert), "Alert must win highest priority")

        let resolvedHeadsUp = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: true,
            pomodoroRunning: true,
            pomodoroPaused: false,
            showPausedPomodoroInNotch: true,
            isMusicPlaying: true
        )
        precondition(resolvedHeadsUp == .compact(.meeting), "Meeting heads-up must precede Pomodoro")

        let resolvedRunningWinsMusic = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: false,
            pomodoroRunning: true,
            pomodoroPaused: false,
            showPausedPomodoroInNotch: true,
            isMusicPlaying: true
        )
        precondition(resolvedRunningWinsMusic == .compact(.pomodoro), "Running Pomodoro must precede Music")

        let resolvedMusicWinsPaused = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: false,
            pomodoroRunning: false,
            pomodoroPaused: true,
            showPausedPomodoroInNotch: true,
            isMusicPlaying: true
        )
        precondition(resolvedMusicWinsPaused == .compact(.music), "Playing Music must precede paused Pomodoro")

        let resolvedPausedShown = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: false,
            pomodoroRunning: false,
            pomodoroPaused: true,
            showPausedPomodoroInNotch: true,
            isMusicPlaying: false
        )
        precondition(resolvedPausedShown == .compact(.pomodoro), "Paused Pomodoro should show when music is silent and toggle is ON")

        let resolvedPausedHidden = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: false,
            pomodoroRunning: false,
            pomodoroPaused: true,
            showPausedPomodoroInNotch: false,
            isMusicPlaying: false
        )
        precondition(resolvedPausedHidden == .idle, "Paused Pomodoro should return Idle when music is silent and toggle is OFF")
    }

    private static func checkSystemLogic() {
        let gb: UInt64 = 1_073_741_824
        let mb: UInt64 = 1_048_576
        let snapNominal = MemorySnapshot(
            totalBytes: 16 * gb,
            appBytes: 6 * gb,
            wiredBytes: 2 * gb,
            compressedBytes: 1 * gb,
            swapUsedBytes: 256 * mb,
            freeBytes: 7 * gb
        )
        precondition(snapNominal.usedBytes == 9 * gb, "Used bytes sum mismatch")
        precondition(snapNominal.usedPercent == 56, "Expected ~56% RAM usage, got \(snapNominal.usedPercent)")
        precondition(snapNominal.pressureLevel == .nominal, "Expected nominal pressure")
        precondition(MemorySnapshot.formatBytes(12 * gb) == "12.0 GB", "GB formatting mismatch")
        precondition(MemorySnapshot.formatBytes(512 * mb) == "512 MB", "MB formatting mismatch")

        let snapCritical = MemorySnapshot(
            totalBytes: 16 * gb,
            appBytes: 10 * gb,
            wiredBytes: 3 * gb,
            compressedBytes: 1 * gb,
            swapUsedBytes: 2 * gb,
            freeBytes: 2 * gb
        )
        precondition(snapCritical.usedPercent == 88, "Critical RAM percent mismatch")
        precondition(snapCritical.pressureLevel == .critical, "Expected critical pressure >=85%")

        let samplePS = """
          120 512000 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
          450 2097152 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
          890 1048576 /Applications/Visual Studio Code.app/Contents/MacOS/Code Helper
          999 409600 /Users/dev/build/Floqy.app/Contents/MacOS/Floqy
        """
        let consumers = SystemLogic.parseTopMemoryProcesses(psOutput: samplePS, limit: 5, selfPID: 999)
        precondition(consumers.count == 2, "Protected/self processes must be filtered: got \(consumers.count)")
        precondition(consumers[0].pid == 450 && consumers[0].name == "Google Chrome", "Top consumer mismatch")
        precondition(consumers[0].residentBytes == 2 * gb, "Resident byte conversion mismatch")

        let sampleLsof = """
        p101
        cnode
        n*:3000
        p102
        cpostgres
        n127.0.0.1:5432
        p103
        ccustom
        n*:9099
        p104
        cother
        n*:3000
        p105
        cephem
        n*:55100
        """
        let ports = SystemLogic.parseListeningPorts(lsofOutput: sampleLsof, limit: 10)
        precondition(ports.count == 3, "Duplicate and ephemeral ports must be filtered: got \(ports.count)")
        precondition(ports[0].port == 3000 && ports[0].isHTTP, "Preferred dev port ordering/HTTP flag mismatch")
        precondition(ports[1].port == 5432 && !ports[1].isHTTP, "Postgres port should not be flagged HTTP")
        precondition(ports[2].port == 9099, "Fallback ascending port mismatch")

        let resolvedMem = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: false,
            pomodoroRunning: false,
            pomodoroPaused: true,
            showPausedPomodoroInNotch: true,
            isMemoryAlertActive: true,
            isMusicPlaying: true
        )
        precondition(resolvedMem == .compact(.memory), "High RAM alert must precede Music & paused Pomodoro")
    }
}

private extension PomodoroState {
    mutating func toggleForCheck() {
        isRunning = true
    }
}
