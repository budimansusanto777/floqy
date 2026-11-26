import Foundation

enum MusicSource: String, Equatable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
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
            guard let text = raw, !text.isEmpty else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                guard let url = match.url, url.scheme?.lowercased() == "https" else { continue }
                let trimmed = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)>]\"'"))
                guard let cleanURL = URL(string: trimmed),
                      meetingProvider(for: cleanURL) != nil else { continue }
                return cleanURL
            }
        }
        return nil
    }

    static func meetingProvider(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path.lowercased()
        if host == "meet.google.com", path.hasPrefix("/"), path.count > 1 {
            return "Google Meet"
        }
        if host == "zoom.us" || host.hasSuffix(".zoom.us"),
           path.hasPrefix("/j/") || path.hasPrefix("/w/") {
            return "Zoom"
        }
        if host == "teams.microsoft.com",
           path.hasPrefix("/l/meetup-join/") || path.hasPrefix("/meet/") {
            return "Teams"
        }
        if host == "teams.live.com", path.hasPrefix("/meet/") {
            return "Teams"
        }
        return nil
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
