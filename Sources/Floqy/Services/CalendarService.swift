import AppKit
import Combine
import EventKit
import Foundation

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
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

    private var store = EKEventStore()
    private var storeObserver: NSObjectProtocol?
    private var refreshTimer: Timer?

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
        attachStoreObserver()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.now = Date()
                self?.refreshEvents()
            }
        }

        refreshEvents()
    }

    func stop() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
            self.storeObserver = nil
        }
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func requestAccess() {
        Task { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            _ = try? await store.requestFullAccessToEvents()
            // Recreate EKEventStore after permission grant so cached empty sources reload cleanly.
            store = EKEventStore()
            attachStoreObserver()
            store.refreshSourcesIfNecessary()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
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

    func refreshEvents() {
        now = Date()
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard authorizationStatus == .fullAccess else {
            syncedCalendarCount = 0
            syncedCalendarNames = []
            upcomingEvents = []
            monthEventsByDay = [:]
            return
        }

        store.refreshSourcesIfNecessary()
        let calendars = store.calendars(for: .event)
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
        let predicate = store.predicateForEvents(withStart: queryStart, end: queryEnd, calendars: calendars)

        let sortedItems: [CalendarEventItem] = store.events(matching: predicate)
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
                    event.notes
                ])
                let provider = meetingURL.flatMap { CalendarLogic.meetingProvider(for: $0) }
                let rangeText = event.isAllDay
                    ? "All day"
                    : "\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))"
                let fallbackTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)

                return CalendarEventItem(
                    id: event.eventIdentifier ?? "\(event.startDate.timeIntervalSince1970)-\(fallbackTitle ?? "event")",
                    title: (fallbackTitle?.isEmpty == false ? fallbackTitle! : "Untitled Event"),
                    startDate: event.startDate,
                    endDate: event.endDate,
                    timeRangeText: rangeText,
                    meetingURL: meetingURL,
                    meetingProvider: provider
                )
            }

        upcomingEvents = Array(
            sortedItems
                .filter { $0.endDate > currentDate && $0.startDate <= upcomingEnd }
                .prefix(3)
        )
        monthEventsByDay = Dictionary(grouping: sortedItems.filter {
            $0.startDate >= monthBounds.start && $0.startDate < monthBounds.end
        }) { CalendarLogic.dayKey(for: $0.startDate) }
    }

    private func attachStoreObserver() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
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
