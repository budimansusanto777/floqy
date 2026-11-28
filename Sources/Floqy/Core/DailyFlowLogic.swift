import Foundation

enum MusicSource: String, CaseIterable, Identifiable, Equatable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }
}

struct NowPlayingTrack: Equatable {
    let title: String
    let artist: String
    let album: String
    let source: MusicSource
    let duration: TimeInterval
    var position: TimeInterval
    var isPlaying: Bool
    let artworkURL: URL?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, max(0.0, position / duration))
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let clamped = max(0, Int(seconds.rounded(.down)))
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

struct PomodoroState: Equatable {
    static let defaultDurationMinutes = 25
    static let minDurationMinutes = 1
    static let maxDurationMinutes = 120
    static let defaultDuration = defaultDurationMinutes * 60

    var durationSeconds: Int
    var remainingSeconds: Int
    var isRunning: Bool

    var durationMinutes: Int {
        max(Self.minDurationMinutes, durationSeconds / 60)
    }

    var isPaused: Bool {
        !isRunning && remainingSeconds > 0 && remainingSeconds < durationSeconds
    }

    var remainingProgress: Double {
        min(1.0, max(0.0, Double(remainingSeconds) / Double(max(1, durationSeconds))))
    }

    init(
        remainingSeconds: Int = defaultDuration,
        isRunning: Bool = false,
        durationSeconds: Int? = nil
    ) {
        let resolvedDuration = durationSeconds ?? Self.defaultDuration
        self.durationSeconds = max(Self.minDurationMinutes * 60, resolvedDuration)
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
    }

    init(durationMinutes: Int) {
        let clamped = min(Self.maxDurationMinutes, max(Self.minDurationMinutes, durationMinutes))
        let total = clamped * 60
        self.durationSeconds = total
        self.remainingSeconds = total
        self.isRunning = false
    }

    var formattedTime: String {
        let clamped = max(0, remainingSeconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// Advances the timer by one second and returns true when the countdown reaches zero.
    mutating func tick() -> Bool {
        guard isRunning else { return false }
        if remainingSeconds > 1 {
            remainingSeconds -= 1
            return false
        }
        remainingSeconds = 0
        isRunning = false
        return true
    }

    mutating func setDuration(minutes: Int) {
        let clamped = min(Self.maxDurationMinutes, max(Self.minDurationMinutes, minutes))
        durationSeconds = clamped * 60
        remainingSeconds = durationSeconds
        isRunning = false
    }

    var isAtInitialStart: Bool {
        !isRunning && remainingSeconds == durationSeconds
    }

    static func currentRound(completedSessions: Int) -> Int {
        (max(0, completedSessions) % 4) + 1
    }

    static func lastCompletedRound(completedSessions: Int) -> Int {
        guard completedSessions > 0 else { return 1 }
        return ((completedSessions - 1) % 4) + 1
    }

    mutating func reset() {
        isRunning = false
        remainingSeconds = durationSeconds
    }
}

struct MonthGridCell: Identifiable, Equatable {
    let id: String
    let date: Date?
    let dayNumber: Int?
}

enum MeetingAlertStage: Equatable {
    case headsUp(minutesRemaining: Int)
    case startingNow
}

enum CalendarLogic {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func extractMeetingURL(from candidates: [String?]) -> URL? {
        guard let detector = linkDetector else { return nil }
        for raw in candidates {
            guard let rawText = raw, !rawText.isEmpty else { continue }
            let text = rawText.replacingOccurrences(of: "&amp;", with: "&")
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                guard let url = match.url,
                      let scheme = url.scheme?.lowercased(),
                      scheme == "https" || scheme == "http" || scheme == "zoommtg" else { continue }
                let trimmed = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)>]\"'<"))
                guard let parsedURL = URL(string: trimmed) else { continue }
                let normalizedURL: URL
                if scheme == "http",
                   var components = URLComponents(url: parsedURL, resolvingAgainstBaseURL: false) {
                    components.scheme = "https"
                    normalizedURL = components.url ?? parsedURL
                } else {
                    normalizedURL = parsedURL
                }
                guard meetingProvider(for: normalizedURL) != nil else { continue }
                return normalizedURL
            }
        }
        return nil
    }

    static func meetingProvider(for url: URL) -> String? {
        let scheme = url.scheme?.lowercased()
        if scheme == "zoommtg" {
            return "Zoom"
        }
        guard scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return nil }
        let path = url.path.lowercased()
        if host == "meet.google.com", path.hasPrefix("/"), path.count > 1 {
            return "Google Meet"
        }
        if host == "zoom.us" || host.hasSuffix(".zoom.us"),
           path.hasPrefix("/j/") || path.hasPrefix("/w/") || path.hasPrefix("/s/") || path.hasPrefix("/my/") {
            return "Zoom"
        }
        if host == "teams.microsoft.com",
           path.hasPrefix("/l/meetup-join/") || path.hasPrefix("/meet/") || path.hasPrefix("/dl/") {
            return "Teams"
        }
        if host == "teams.live.com", path.hasPrefix("/meet/") {
            return "Teams"
        }
        if host == "webex.com" || host.hasSuffix(".webex.com"), path.count > 1 {
            return "Webex"
        }
        if host == "app.slack.com", path.hasPrefix("/huddle/") {
            return "Slack Huddle"
        }
        if (host.hasSuffix(".larksuite.com") || host.hasSuffix(".feishu.cn")),
           (host.hasPrefix("vc.") || host.hasPrefix("meetings.") || path.contains("/vc/")) {
            return "Lark"
        }
        if host == "meet.jit.si", path.count > 1 {
            return "Jitsi"
        }
        if host == "whereby.com", path.count > 1 {
            return "Whereby"
        }
        if host == "chime.aws", path.count > 1 {
            return "Chime"
        }
        if (host == "meet.goto.com" || host == "global.gotomeeting.com"), path.count > 1 {
            return "GoTo"
        }
        return nil
    }

    static func prioritizeUpcoming<T>(
        _ items: [T],
        isAllDay: (T) -> Bool,
        startDate: (T) -> Date,
        endDate: (T) -> Date,
        now: Date,
        upcomingEnd: Date,
        limit: Int = 10
    ) -> [T] {
        let filtered = items.filter { endDate($0) > now && startDate($0) <= upcomingEnd }
        let sorted = filtered.sorted { lhs, rhs in
            let lhsAllDay = isAllDay(lhs)
            let rhsAllDay = isAllDay(rhs)
            if lhsAllDay != rhsAllDay {
                return !lhsAllDay && rhsAllDay
            }
            return startDate(lhs) < startDate(rhs)
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    static func meetingAlertStage(now: Date, startDate: Date, endDate: Date) -> MeetingAlertStage? {
        if now >= startDate && now < endDate && now.timeIntervalSince(startDate) <= 120 {
            return .startingNow
        }
        let delta = startDate.timeIntervalSince(now)
        if delta > 0 && delta <= 300 {
            return .headsUp(minutesRemaining: max(1, Int(ceil(delta / 60))))
        }
        return nil
    }

    static func formatCountdown(from now: Date, to start: Date, end: Date) -> String {
        if now >= end {
            return "Ended"
        }
        if now >= start {
            return "Now"
        }
        let deltaSeconds = start.timeIntervalSince(now)
        if deltaSeconds <= 0 {
            return "Now"
        }

        let minutes = Int(ceil(deltaSeconds / 60))
        if minutes <= 60 {
            return "In \(minutes) min"
        }

        let hours = Int(deltaSeconds / 3600)
        if hours < 24 {
            let remMinutes = (Int(deltaSeconds) % 3600) / 60
            return remMinutes > 0 ? "In \(hours)h \(remMinutes)m" : "In \(hours)h"
        }

        let calendar = Calendar.current
        if calendar.isDateInTomorrow(start) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: start)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    static func monthBounds(for monthAnchor: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        let start = calendar.date(from: comps) ?? calendar.startOfDay(for: monthAnchor)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(31 * 24 * 3600)
        return (start, end)
    }

    static func monthGridCells(for monthAnchor: Date, calendar: Calendar = .current) -> [MonthGridCell] {
        let bounds = monthBounds(for: monthAnchor, calendar: calendar)
        guard let dayRange = calendar.range(of: .day, in: .month, for: bounds.start) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: bounds.start) // 1 = Sun ... 7 = Sat
        let leadingBlanks = max(0, firstWeekday - 1)

        var cells: [MonthGridCell] = (0..<leadingBlanks).map { idx in
            MonthGridCell(id: "blank-\(idx)", date: nil, dayNumber: nil)
        }

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: bounds.start) {
                cells.append(MonthGridCell(id: dayKey(for: date, calendar: calendar), date: date, dayNumber: day))
            }
        }
        return cells
    }
}
