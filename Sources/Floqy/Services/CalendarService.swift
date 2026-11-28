import AppKit
import Combine
import EventKit
import Foundation

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let timeRangeText: String
    let meetingURL: URL?
    let meetingProvider: String?
}

/// Reads upcoming and monthly calendar events from macOS EventKit (syncing Google, iCloud, and Exchange/Teams).
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var syncedCalendarCount: Int = 0
    @Published private(set) var syncedCalendarNames: [String] = []
    @Published private(set) var upcomingEvents: [CalendarEventItem] = []
    @Published private(set) var monthEventsByDay: [String: [CalendarEventItem]] = [:]
    @Published var displayedMonth: Date
    @Published var selectedDate: Date
    @Published private(set) var now: Date = Date()

    private var store: EKEventStore?
    private var storeObserver: NSObjectProtocol?
    private var refreshTimer: Timer?
    private var delayedRefreshTask: Task<Void, Never>?
    private var refreshTickCount = 0
    private var lastRefreshDayKey = CalendarLogic.dayKey(for: Date())
    private var lastRefreshDate: Date = .distantPast
    private var isDisplayAsleep = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init() {
        let today = Date()
        self.selectedDate = Calendar.current.startOfDay(for: today)
        self.displayedMonth = CalendarLogic.monthBounds(for: today).start
    }

    func start() {
        stop()
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if !isDisplayAsleep {
            startRefreshTimer()
            refreshEvents()
        }
    }

    func setDisplayAsleep(_ asleep: Bool) {
        guard isDisplayAsleep != asleep else { return }
        isDisplayAsleep = asleep
        if asleep {
            delayedRefreshTask?.cancel()
            delayedRefreshTask = nil
            refreshTimer?.invalidate()
            refreshTimer = nil
            clearStore()
        } else {
            startRefreshTimer()
            refreshEvents()
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = Date()
                self.refreshTickCount += 1
                let latestStatus = EKEventStore.authorizationStatus(for: .event)
                let hasEndedUpcoming = self.upcomingEvents.contains { $0.endDate <= self.now }
                if latestStatus != self.authorizationStatus
                    || self.refreshTickCount >= 4
                    || hasEndedUpcoming
                    || CalendarLogic.dayKey(for: self.now) != self.lastRefreshDayKey {
                    self.refreshEvents()
                }
            }
        }
    }

    func stop() {
        delayedRefreshTask?.cancel()
        delayedRefreshTask = nil
        clearStore()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func requestAccess() {
        Task { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            let initialStore = ensureStore()
            _ = try? await initialStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if authorizationStatus == .fullAccess {
                // Recreate EKEventStore after permission grant so cached empty sources reload cleanly.
                let freshStore = EKEventStore()
                store = freshStore
                attachStoreObserver(to: freshStore)
                freshStore.refreshSourcesIfNecessary()
            } else {
                clearStore()
            }
            refreshEvents()
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    func changeDisplayedMonth(by delta: Int) {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else {
            return
        }
        displayedMonth = CalendarLogic.monthBounds(for: nextMonth).start
        refreshEvents()
    }

    func events(on date: Date) -> [CalendarEventItem] {
        monthEventsByDay[CalendarLogic.dayKey(for: date)] ?? []
    }

    func hasEvents(on date: Date) -> Bool {
        !(monthEventsByDay[CalendarLogic.dayKey(for: date)] ?? []).isEmpty
    }

    func forceRefresh() {
        refreshEvents()
        delayedRefreshTask?.cancel()
        delayedRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.refreshEvents()
        }
    }

    func refreshIfStale(minInterval: TimeInterval = 15) {
        let latestStatus = EKEventStore.authorizationStatus(for: .event)
        if latestStatus != authorizationStatus || Date().timeIntervalSince(lastRefreshDate) >= minInterval {
            refreshEvents()
        }
    }

    func refreshEvents() {
        now = Date()
        refreshTickCount = 0
        lastRefreshDate = now
        lastRefreshDayKey = CalendarLogic.dayKey(for: now)
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard authorizationStatus == .fullAccess else {
            clearStore()
            syncedCalendarCount = 0
            syncedCalendarNames = []
            upcomingEvents = []
            monthEventsByDay = [:]
            return
        }

        let eventStore = ensureStore()
        eventStore.reset()
        eventStore.refreshSourcesIfNecessary()
        let calendars = eventStore.calendars(for: .event)
        syncedCalendarCount = calendars.count
        syncedCalendarNames = calendars.map(\.title)

        guard !calendars.isEmpty else {
            upcomingEvents = []
            monthEventsByDay = [:]
            return
        }

        let currentDate = now
        let monthBounds = CalendarLogic.monthBounds(for: displayedMonth)
        let upcomingStart = currentDate.addingTimeInterval(-15 * 60)
        let upcomingEnd = currentDate.addingTimeInterval(7 * 24 * 3600)

        let queryStart = min(monthBounds.start, upcomingStart)
        let queryEnd = max(monthBounds.end, upcomingEnd)
        let predicate = eventStore.predicateForEvents(withStart: queryStart, end: queryEnd, calendars: calendars)

        let sortedItems: [CalendarEventItem] = eventStore.events(matching: predicate)
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return !lhs.isAllDay && rhs.isAllDay
            }
            .map { event in
                let meetingURL = CalendarLogic.extractMeetingURL(from: [
                    event.url?.absoluteString,
                    event.location,
                    event.structuredLocation?.title,
                    event.notes
                ])
                let provider = meetingURL.flatMap { CalendarLogic.meetingProvider(for: $0) }
                let rangeText = event.isAllDay
                    ? "All day"
                    : "\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))"
                let fallbackTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)

                let baseID = event.eventIdentifier ?? (fallbackTitle?.isEmpty == false ? fallbackTitle! : "event")
                return CalendarEventItem(
                    id: "\(baseID)-\(Int(event.startDate.timeIntervalSince1970))",
                    title: (fallbackTitle?.isEmpty == false ? fallbackTitle! : "Untitled Event"),
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    timeRangeText: rangeText,
                    meetingURL: meetingURL,
                    meetingProvider: provider
                )
            }

        upcomingEvents = CalendarLogic.prioritizeUpcoming(
            sortedItems,
            isAllDay: \.isAllDay,
            startDate: \.startDate,
            endDate: \.endDate,
            now: currentDate,
            upcomingEnd: upcomingEnd,
            limit: 10
        )
        monthEventsByDay = Dictionary(grouping: sortedItems.filter {
            $0.startDate >= monthBounds.start && $0.startDate < monthBounds.end
        }) { CalendarLogic.dayKey(for: $0.startDate) }
    }

    private func ensureStore() -> EKEventStore {
        if let store { return store }
        let created = EKEventStore()
        store = created
        attachStoreObserver(to: created)
        return created
    }

    private func clearStore() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
            self.storeObserver = nil
        }
        store = nil
    }

    private func attachStoreObserver(to eventStore: EKEventStore) {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshEvents()
            }
        }
    }

    func openMeeting(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
