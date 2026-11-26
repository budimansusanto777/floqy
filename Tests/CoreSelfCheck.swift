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
        checkAIActivityLogic()
        checkHardwareStatusAndRestingEyesLogic()
        print("CoreSelfCheck: 13/13 checks passed.")
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
        precondition(expandedOverview.width == 596 + NotchGeometry.horizontalPadding, "Expanded panel width mismatch")

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

        precondition(CalendarLogic.meetingProvider(for: URL(string: "https://evil.com/meet.google.com/abc-defg-hij")!) == nil, "Spoofed Meet path must be rejected")
        precondition(CalendarLogic.meetingProvider(for: URL(string: "https://phish-zoom.us/j/123456")!) == nil, "Spoofed Zoom host must be rejected")
        precondition(CalendarLogic.meetingProvider(for: URL(string: "https://evil.com/teams.microsoft.com/meet/123")!) == nil, "Spoofed Teams path must be rejected")
        precondition(CalendarLogic.meetingProvider(for: URL(string: "https://meet.google.com/abc-defg-hij")!) == "Google Meet", "Valid Meet URL mismatch")
        precondition(CalendarLogic.meetingProvider(for: URL(string: "https://us02web.zoom.us/j/123456")!) == "Zoom", "Valid Zoom URL mismatch")
        precondition(CalendarLogic.meetingProvider(for: URL(string: "https://teams.live.com/meet/987654")!) == "Teams", "Valid Teams URL mismatch")

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        precondition(
            CalendarLogic.formatCountdown(from: now, to: now.addingTimeInterval(-60), end: now.addingTimeInterval(600)) == "Now",
            "Active meeting should show Now"
        )
        precondition(
            CalendarLogic.formatCountdown(from: now, to: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-1)) == "Ended",
            "Ended meeting should show Ended"
        )
        precondition(
            CalendarLogic.formatCountdown(from: now, to: now.addingTimeInterval(-3600), end: now) == "Ended",
            "Meeting ending exactly now should show Ended"
        )

        var freshPomodoro = PomodoroState(durationMinutes: 1)
        precondition(freshPomodoro.isAtInitialStart, "Fresh stopped Pomodoro should be at initial start")
        freshPomodoro.isRunning = true
        precondition(!freshPomodoro.isAtInitialStart, "Running Pomodoro should not report initial start")
        _ = freshPomodoro.tick()
        freshPomodoro.isRunning = false
        precondition(!freshPomodoro.isAtInitialStart, "Paused Pomodoro mid-countdown should not report initial start")
        freshPomodoro.remainingSeconds = 0
        precondition(!freshPomodoro.isAtInitialStart, "Completed Pomodoro should not report initial start")

        precondition(PomodoroState.currentRound(completedSessions: 0) == 1, "Initial round must be 1")
        precondition(PomodoroState.lastCompletedRound(completedSessions: 1) == 1, "First completed alert must say Session 1")
        precondition(PomodoroState.currentRound(completedSessions: 1) == 2, "Next round after 1 completion must be 2")
        precondition(PomodoroState.lastCompletedRound(completedSessions: 4) == 4, "Fourth completed alert must say Session 4")
        precondition(PomodoroState.lastCompletedRound(completedSessions: 5) == 1, "Fifth completed alert wraps to Session 1")
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
        precondition(ClipboardLogic.shouldIgnorePasteboardTypes(["org.nspasteboard.ConcealedType", "public.utf8-plain-text"]), "Concealed pasteboard type must be ignored")
        precondition(ClipboardLogic.shouldIgnorePasteboardTypes(["org.nspasteboard.TransientType"]), "Transient pasteboard type must be ignored")
        precondition(ClipboardLogic.shouldIgnorePasteboardTypes(["com.agilebits.onepassword"]), "1Password pasteboard type must be ignored")
        precondition(!ClipboardLogic.shouldIgnorePasteboardTypes(["public.utf8-plain-text"]), "Plain text pasteboard must be captured")

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
        let centeredIdle = geometry.centeredFrame(size: CGSize(width: 196, height: 54))
        let centeredExpanded = geometry.centeredFrame(size: CGSize(width: 620, height: 268))
        precondition(abs(centeredIdle.midX - round(geometry.screenFrame.midX)) <= 0.5 && centeredIdle.maxY == geometry.screenFrame.maxY, "Idle centeredFrame must anchor top-center")
        precondition(abs(centeredExpanded.midX - round(geometry.screenFrame.midX)) <= 0.5 && centeredExpanded.maxY == geometry.screenFrame.maxY, "Expanded centeredFrame must anchor top-center")
        precondition(alertSize.height > compactSize.height, "Alert shell must expand vertically beyond compact height")
        precondition(CGRect(origin: .zero, size: alertFrame.size).contains(alertHit), "Alert hit rect must fit inside alert panel")

        var shape = NotchShellShape(topEarRadius: 12, bottomCornerRadius: 22)
        shape.animatableData = .init(.init(6, 18), .init(0, 0))
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

    private static func checkAIActivityLogic() {
        let parsedDone = AIActivityLogic.parseIncomingURL(URL(string: "floqy://ai?agent=antigravity&state=done")!)
        precondition(parsedDone == AIAgentEvent(agent: .antigravity, state: .done), "Failed to parse Antigravity done URL")
        let parsedWorking = AIActivityLogic.parseIncomingURL(URL(string: "floqy://ai?agent=geminiCLI&state=working")!)
        precondition(parsedWorking == AIAgentEvent(agent: .geminiCLI, state: .working), "Failed to parse Gemini CLI working URL")
        precondition(AIActivityLogic.parseIncomingURL(URL(string: "https://example.com/ai")!) == nil, "Non-floqy URL must be ignored")

        // Antigravity hooks.json non-destructive upsert/remove
        let existingAgy = #"{"user-hook":{"enabled":true}}"#
        let mergedAgy = AIActivityLogic.upsertHook(in: existingAgy, for: .antigravity)
        precondition(mergedAgy?.contains("user-hook") == true && AIActivityLogic.isHookInstalled(in: mergedAgy, for: .antigravity), "Antigravity hook upsert failed")
        let cleanedAgy = AIActivityLogic.removeHook(from: mergedAgy, for: .antigravity)
        precondition(cleanedAgy?.contains("user-hook") == true && !AIActivityLogic.isHookInstalled(in: cleanedAgy, for: .antigravity), "Antigravity hook remove failed")

        // Gemini CLI settings.json non-destructive upsert/remove
        let existingGem = #"{"theme":"dark","hooks":{"BeforeTool":[{"matcher":"*","hooks":[{"name":"other","type":"command","command":"echo 1"}]}]}}"#
        let mergedGem = AIActivityLogic.upsertHook(in: existingGem, for: .geminiCLI)
        precondition(mergedGem?.contains("BeforeTool") == true && AIActivityLogic.isHookInstalled(in: mergedGem, for: .geminiCLI), "Gemini CLI hook upsert failed")
        let cleanedGem = AIActivityLogic.removeHook(from: mergedGem, for: .geminiCLI)
        precondition(cleanedGem?.contains("BeforeTool") == true && !AIActivityLogic.isHookInstalled(in: cleanedGem, for: .geminiCLI), "Gemini CLI hook remove failed")

        // Claude Code settings.json non-destructive upsert/remove
        let existingClaude = #"{"model":"sonnet","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say hi"}]}]}}"#
        let mergedClaude = AIActivityLogic.upsertHook(in: existingClaude, for: .claudeCode)
        precondition(mergedClaude?.contains("say hi") == true && AIActivityLogic.isHookInstalled(in: mergedClaude, for: .claudeCode), "Claude Code hook upsert failed")
        let cleanedClaude = AIActivityLogic.removeHook(from: mergedClaude, for: .claudeCode)
        precondition(cleanedClaude?.contains("say hi") == true && !AIActivityLogic.isHookInstalled(in: cleanedClaude, for: .claudeCode), "Claude Code hook remove failed")

        // Invalid JSON guard
        precondition(AIActivityLogic.upsertHook(in: "{bad json", for: .antigravity) == nil, "Invalid JSON must fail safely")

        // Local Claude JSONL usage parsing
        let now = Date()
        let iso = ISO8601DateFormatter()
        let recentTS = iso.string(from: now.addingTimeInterval(60))
        let oldTS = iso.string(from: now.addingTimeInterval(-3600))
        let sampleJSONL = """
        {bad json line without usage
        {"timestamp":"\(recentTS)","message":{"model":"claude-3-5-sonnet","content":"no usage object"}}
        {"timestamp":"\(oldTS)","message":{"model":"claude-3-5-sonnet","usage":{"input_tokens":500,"output_tokens":500}}}
        {"timestamp":"\(recentTS)","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":1000,"output_tokens":200,"cache_read_input_tokens":300,"cache_creation_input_tokens":100}}}
        """
        let summary = AIActivityLogic.parseClaudeJSONLUsage(jsonlContent: sampleJSONL, since: now)
        precondition(summary.inputTokens == 1000 && summary.outputTokens == 200 && summary.totalTokens == 1600, "Claude JSONL usage parse mismatch")
        precondition(summary.estimatedCostUSD > 0, "Claude JSONL cost must be positive")

        // Priority with active AI work
        let resolvedAI = NotchMode.resolvedCollapsedMode(
            activeAlert: nil,
            hasMeetingHeadsUp: false,
            pomodoroRunning: false,
            pomodoroPaused: false,
            showPausedPomodoroInNotch: true,
            hasActiveAIWork: true,
            isMemoryAlertActive: true,
            isMusicPlaying: true
        )
        precondition(resolvedAI == .compact(.ai), "Active AI work must precede Memory & Music")
    }

    private static func checkHardwareStatusAndRestingEyesLogic() {
        let unplugged = BatteryStatus(percentage: 64, isCharging: false, isPluggedIn: false, timeToFullMinutes: nil)
        let plugged = BatteryStatus(percentage: 64, isCharging: true, isPluggedIn: true, timeToFullMinutes: 42)
        precondition(plugged.formattedETA == "42m to full", "Battery ETA minute formatting mismatch")
        precondition(BatteryStatus(percentage: 50, isCharging: true, isPluggedIn: true, timeToFullMinutes: 75).formattedETA == "1h 15m to full", "Battery ETA hour formatting mismatch")
        precondition(BatteryStatus(percentage: 100, isCharging: false, isPluggedIn: true, timeToFullMinutes: 0).formattedETA == nil, "Zero ETA should be nil")

        precondition(!HardwareStatusLogic.shouldTriggerChargingCard(previous: nil, current: plugged), "Initial baseline must not trigger charging card")
        precondition(HardwareStatusLogic.shouldTriggerChargingCard(previous: unplugged, current: plugged), "Unplugged -> plugged must trigger charging card")
        precondition(!HardwareStatusLogic.shouldTriggerChargingCard(previous: plugged, current: plugged), "Already charging must not retrigger")

        precondition(HardwareStatusLogic.isAirPodsName("Budiman's AirPods Pro"), "AirPods detection mismatch")
        precondition(HardwareStatusLogic.isLikelyHeadphoneDevice(name: "WH-1000XM5", isBluetooth: true, isWiredHeadphonePort: false), "Bluetooth headset should be accepted")
        precondition(!HardwareStatusLogic.isLikelyHeadphoneDevice(name: "MacBook Pro Speakers", isBluetooth: false, isWiredHeadphonePort: false), "Built-in speakers must be excluded")
        precondition(HardwareStatusLogic.isLikelyHeadphoneDevice(name: "External Headphones", isBluetooth: false, isWiredHeadphonePort: true), "Wired headphone jack must be accepted")

        let airpods = HeadphoneStatus(name: "AirPods Pro", batteryPercent: 82, isAirPods: true)
        precondition(!HardwareStatusLogic.shouldTriggerHeadphoneCard(previousDeviceName: nil, current: airpods), "Initial audio baseline must not trigger card")
        precondition(HardwareStatusLogic.shouldTriggerHeadphoneCard(previousDeviceName: "MacBook Pro Speakers", current: airpods), "Switching to headphones must trigger card")
        precondition(!HardwareStatusLogic.shouldTriggerHeadphoneCard(previousDeviceName: "AirPods Pro", current: airpods), "Same device must not retrigger")

        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 944, width: 656, height: 38),
            auxiliaryTopRightArea: CGRect(x: 856, y: 944, width: 656, height: 38)
        )
        precondition(IdleAppearance.allCases.count == 6, "IdleAppearance must expose Off, Eyes, Cat, Dog, Wave, and Horizon")
        precondition(!IdleAppearance.off.isVisible && IdleAppearance.cat.isVisible && IdleAppearance.horizon.isVisible, "Only Off hides the idle mini-chin")
        precondition(IdleAppearance.cat.isSideWing && IdleAppearance.dog.isSideWing && !IdleAppearance.eyes.isSideWing, "Cat and Dog use single-row side wings")
        precondition(!IdleAppearance.cat.usesBottomChin && IdleAppearance.eyes.usesBottomChin, "Only non-wing visible idle styles use bottom chin")
        precondition(IdleNotchWidth.allCases.count == 2, "IdleNotchWidth must expose Compact and Full")
        precondition(NotchThemePreset.allCases.count == 7, "NotchThemePreset must expose 7 presets")
        precondition(NotchThemePreset.pureWhite.isLight && NotchThemePreset.sakuraBlush.isLight && NotchThemePreset.wallpaperLight.isLight, "Light theme flags mismatch")
        precondition(!NotchThemePreset.obsidian.isLight && !NotchThemePreset.midnight.isLight && !NotchThemePreset.roseVelvet.isLight && !NotchThemePreset.wallpaperDark.isLight, "Dark theme flags mismatch")
        precondition(NotchThemePreset.wallpaperDark.usesWallpaper && NotchThemePreset.wallpaperLight.usesWallpaper && !NotchThemePreset.sakuraBlush.usesWallpaper, "Wallpaper flag mismatch")
        precondition(NotchThemePreset.resolved(for: .idle, selected: .pureWhite) == .obsidian, "Idle notch must keep Obsidian black")
        precondition(NotchThemePreset.resolved(for: .compact(.music), selected: .sakuraBlush) == .obsidian, "Compact notch must keep Obsidian black")
        precondition(NotchThemePreset.resolved(for: .expanded, selected: .pureWhite) == .pureWhite, "Expanded notch must apply selected theme")
        precondition(DisplayPreference.allCases.count == 3, "DisplayPreference must expose Built-in, Primary, and Follow Cursor")

        let monitorFrames = [
            CGRect(x: 0, y: 0, width: 2560, height: 1440),
            CGRect(x: -1512, y: 0, width: 1512, height: 982)
        ]
        precondition(
            NotchGeometry.resolveScreenIndex(frames: monitorFrames, notchedIndices: [1], preference: .builtInNotch, cursor: CGPoint(x: 100, y: 100)) == 1,
            "Built-in preference must choose the notched screen"
        )
        precondition(
            NotchGeometry.resolveScreenIndex(frames: monitorFrames, notchedIndices: [1], preference: .primary, cursor: CGPoint(x: -400, y: 100)) == 0,
            "Primary preference must choose origin .zero screen"
        )
        precondition(
            NotchGeometry.resolveScreenIndex(frames: monitorFrames, notchedIndices: [1], preference: .followCursor, cursor: CGPoint(x: -300, y: 500)) == 1,
            "Follow cursor must track cursor onto secondary display"
        )
        precondition(
            NotchGeometry.resolveScreenIndex(frames: monitorFrames, notchedIndices: [1], preference: .followCursor, cursor: CGPoint(x: 400, y: 500)) == 0,
            "Follow cursor must track cursor onto primary display"
        )

        let eyesIdle = geometry.shellSize(for: .idle, idleAppearance: .eyes)
        precondition(eyesIdle.height == geometry.notchSafeTopHeight + 20, "Bottom-chin idle must extend 20pt below hardware camera")
        precondition(geometry.earPadding(for: .idle, idleAppearance: .eyes, idleWidth: .compact) == 0, "Compact idle mini-chin sits flush with camera top without side ears")
        precondition(geometry.earPadding(for: .idle, idleAppearance: .eyes, idleWidth: .full) == NotchGeometry.horizontalPadding, "Full idle width includes concave side ears")
        precondition(geometry.earPadding(for: .idle, idleAppearance: .off, idleWidth: .full) == 0, "Flush Off idle must have zero ear padding")
        precondition(geometry.bottomRadius(for: .idle, idleAppearance: .eyes, idleWidth: .compact) == 12, "Compact idle chin must use 12pt bottom radius")
        precondition(geometry.bottomRadius(for: .idle, idleAppearance: .eyes, idleWidth: .full) == 16, "Full idle width must use 16pt bottom radius")
        precondition(geometry.taperedChinInset(for: .idle, idleAppearance: .eyes, idleWidth: .compact) > 40, "Compact tapered idle chin must inset cleanly from hardware camera edges")
        precondition(geometry.taperedChinInset(for: .idle, idleAppearance: .eyes, idleWidth: .full) == 0, "Full idle width has zero tapered inset")
        precondition(geometry.taperedChinInset(for: .expanded, idleAppearance: .eyes) == 0, "Expanded shell never uses tapered chin inset")

        let catSize = geometry.shellSize(for: .idle, idleAppearance: .cat)
        let catHit = geometry.hitRectInPanel(for: .idle, idleAppearance: .cat)
        let dogHit = geometry.hitRectInPanel(for: .idle, idleAppearance: .dog)
        precondition(catSize.height == geometry.hardwareNotchSize.height, "Side-wing Cat must match camera height on a single row")
        precondition(geometry.leftLeadingInset(for: .idle, idleAppearance: .cat) == 0, "Symmetrical Cat uses both left and right wings")
        precondition(catHit.minX <= 0.5, "Symmetrical Cat hit rect should span both wings")
        precondition(geometry.leftLeadingInset(for: .idle, idleAppearance: .dog) == NotchGeometry.sideWingSlotWidth, "Right-wing Dog must leave leading inset for left menu bar")
        precondition(dogHit.minX >= NotchGeometry.sideWingSlotWidth - 0.5, "Side-wing Dog hit rect must not cover left transparent menu-bar slot")

        let rightWingShape = NotchShellShape(
            topEarRadius: NotchGeometry.earWidth,
            bottomCornerRadius: geometry.bottomRadius(for: .idle, idleAppearance: .dog),
            leftLeadingInset: NotchGeometry.sideWingSlotWidth
        )
        let rightWingPath = rightWingShape.path(in: CGRect(origin: .zero, size: catSize))
        precondition(!rightWingPath.isEmpty && rightWingPath.boundingRect.minX >= NotchGeometry.sideWingSlotWidth - 0.5, "Right-wing shape must stay flush right of left inset")

        var taperedShape = NotchShellShape(
            topEarRadius: 0,
            bottomCornerRadius: geometry.bottomRadius(for: .idle, idleAppearance: .eyes),
            taperedChinInset: geometry.taperedChinInset(for: .idle, idleAppearance: .eyes),
            cameraHeight: geometry.notchSafeTopHeight
        )
        taperedShape.animatableData = .init(.init(4, 13), .init(36, 0))
        precondition(taperedShape.taperedChinInset == 36, "NotchShellShape animatableData must drive taperedChinInset")
        let taperedPath = taperedShape.path(in: CGRect(origin: .zero, size: eyesIdle))
        precondition(!taperedPath.isEmpty, "Tapered mini-chin shape must produce a valid path")
    }
}

private extension PomodoroState {
    mutating func toggleForCheck() {
        isRunning = true
    }
}
