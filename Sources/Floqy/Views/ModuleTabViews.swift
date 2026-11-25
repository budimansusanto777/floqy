import EventKit
import SwiftUI

/// Shared card container with theme-matched surface and border contrast.
struct NotchCard<Content: View>: View {
    @Environment(\.notchThemePreset) private var themePreset
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let palette = NotchColors.palette(for: themePreset)
        content
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    if palette.usesFrostedCards {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.cardSurface)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.cardBorder, lineWidth: 1)
                )
            )
    }
}

// MARK: - 1. Home Tab (Music + Calendar + Pomodoro/Todo Strip)

struct HomeTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var music: MusicService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var productivity: ProductivityService
    @ObservedObject var system: SystemMonitorService

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private static let selectedDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    var body: some View {
        switch manager.homeSubView {
        case .overview:
            overviewLayout
        case .calendar:
            calendarLayout
        }
    }

    private var overviewLayout: some View {
        HStack(spacing: 10) {
            musicCard

            VStack(spacing: 8) {
                calendarCard

                HStack(spacing: 8) {
                    pomodoroTile
                    wingTile(
                        title: "\(productivity.todos.filter { !$0.isDone }.count) todo",
                        icon: "checklist",
                        color: NotchColors.accentPrimary
                    ) {
                        manager.selectTab(.notes)
                    }
                    wingTile(
                        title: "RAM \(system.snapshot.usedPercent)%",
                        icon: "cpu",
                        color: systemPressureColor(system.snapshot.pressureLevel)
                    ) {
                        manager.selectTab(.system)
                    }
                }
                .frame(height: 38)
            }
        }
    }

    private func systemPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .nominal: return NotchColors.statusHealthy
        case .warning: return NotchColors.statusWarning
        case .critical: return NotchColors.statusAlert
        }
    }

    private var calendarLayout: some View {
        HStack(spacing: 10) {
            monthGridCard
                .frame(width: 218)

            selectedDayMeetingsCard
        }
    }

    private var monthGridCard: some View {
        let cells = CalendarLogic.monthGridCells(for: calendar.displayedMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return NotchCard {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(Self.monthFormatter.string(from: calendar.displayedMonth))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    Button {
                        calendar.changeDisplayedMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(width: 20, height: 18)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel("Previous month")

                    Button {
                        calendar.changeDisplayedMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(width: 20, height: 18)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel("Next month")
                }

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(height: 12)
                    }

                    ForEach(cells) { cell in
                        if let date = cell.date, let day = cell.dayNumber {
                            monthDayButton(date: date, day: day)
                        } else {
                            Color.clear.frame(height: 18)
                        }
                    }
                }
            }
        }
    }

    private func monthDayButton(date: Date, day: Int) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: calendar.selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let hasEvents = calendar.hasEvents(on: date)

        return Button {
            calendar.selectDate(date)
        } label: {
            ZStack(alignment: .bottom) {
                Text("\(day)")
                    .font(.system(size: 10, weight: isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? NotchColors.notchBackground
                            : (isToday ? NotchColors.accentPrimary : NotchColors.textPrimary)
                    )
                    .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? NotchColors.accentPrimary : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isToday && !isSelected ? NotchColors.accentPrimary : Color.clear, lineWidth: 1)
                            )
                    )

                if hasEvents {
                    Circle()
                        .fill(isSelected ? NotchColors.notchBackground : NotchColors.accentPrimary)
                        .frame(width: 3, height: 3)
                        .padding(.bottom, 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.selectedDayFormatter.string(from: date))
    }

    private var selectedDayMeetingsCard: some View {
        let dayEvents = calendar.events(on: calendar.selectedDate)
        let isToday = Calendar.current.isDateInToday(calendar.selectedDate)
        let heading = (isToday ? "Today • " : "") + Self.selectedDayFormatter.string(from: calendar.selectedDate)

        return NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(heading)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if calendarNeedsAuth {
                        EmptyView()
                    } else {
                        Text("\(dayEvents.count)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NotchColors.textSecondary)
                    }
                    Button("Overview") {
                        manager.setHomeSubView(.overview)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .accessibilityLabel("Back to Overview")
                    Button {
                        calendar.refreshEvents()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(width: 20, height: 18)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel("Refresh calendar")
                }

                if calendarNeedsAuth {
                    calendarAuthContent
                } else if dayEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No meetings scheduled.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(NotchColors.textPrimary)
                        Text("Select a date with a dot indicator on the calendar.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(NotchColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(dayEvents) { event in
                                calendarMeetingRow(event, showCountdown: isToday || event.startDate > calendar.now)
                            }
                        }
                    }
                }
            }
        }
    }

    private func calendarMeetingRow(_ event: CalendarEventItem, showCountdown: Bool) -> some View {
        let countdown = CalendarLogic.formatCountdown(
            from: calendar.now,
            to: event.startDate,
            end: event.endDate
        )
        let badgeColor = countdown == "Now"
            ? NotchColors.statusHealthy
            : (event.startDate.timeIntervalSince(calendar.now) <= 15 * 60
                ? NotchColors.statusWarning
                : NotchColors.accentPrimary)

        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                        .lineLimit(1)

                    if showCountdown && event.endDate > calendar.now {
                        Text(countdown)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(badgeColor.opacity(0.16)))
                    }
                }
                Text(nextEventSubtitle(for: event))
                    .font(.system(size: 10))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let meetingURL = event.meetingURL {
                Button {
                    calendar.openMeeting(meetingURL)
                } label: {
                    Text("Join")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchColors.notchBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(NotchColors.accentPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(NotchColors.controlSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(NotchColors.cardBorder, lineWidth: 1)
                )
        )
    }

    private var musicCard: some View {
        NotchCard {
            if let track = music.track {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        artworkTile(image: music.artworkImage)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NotchColors.textPrimary)
                                .lineLimit(1)
                            Text("\(track.artist) • \(track.source.rawValue)")
                                .font(.system(size: 11))
                                .foregroundStyle(NotchColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        EqualizerBarsView(isPlaying: track.isPlaying)
                            .frame(height: 14)
                    }

                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(NotchColors.trackBackground)
                                Capsule()
                                    .fill(NotchColors.accentPrimary)
                                    .frame(width: max(4, geo.size.width * track.progress))
                            }
                            .frame(height: 5)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        guard geo.size.width > 0 else { return }
                                        let fraction = value.location.x / geo.size.width
                                        music.seek(to: fraction)
                                    }
                            )
                        }
                        .frame(height: 6)
                        .accessibilityLabel("Track progress")

                        HStack {
                            Text(NowPlayingTrack.formatDuration(track.position))
                            Spacer()
                            Text(NowPlayingTrack.formatDuration(track.duration))
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(NotchColors.textSecondary)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 18) {
                        Button {
                            music.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12.5))
                                .foregroundStyle(NotchColors.textPrimary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 8))
                        .accessibilityLabel("Previous track")

                        Button {
                            music.togglePlayPause()
                        } label: {
                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12.5))
                                .foregroundStyle(NotchColors.notchBackground)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(NotchColors.textPrimary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(track.isPlaying ? "Pause" : "Play")

                        Button {
                            music.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12.5))
                                .foregroundStyle(NotchColors.textPrimary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 8))
                        .accessibilityLabel("Next track")
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Now Playing", systemImage: "music.note")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)

                    Text("No active playback.")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NotchColors.textPrimary)

                    Text("Play audio in Spotify or Apple Music to control tracks here.")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Button {
                        manager.showCompact(.music)
                    } label: {
                        Label("Preview Music Wing", systemImage: "music.note")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchColors.accentPrimary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                }
            }
        }
    }

    @ViewBuilder
    private func artworkTile(image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(NotchColors.controlSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(NotchColors.cardBorder, lineWidth: 1)
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotchColors.accentPrimary)
                )
        }
    }

    private var calendarNeedsAuth: Bool {
        calendar.authorizationStatus != .fullAccess
    }

    @ViewBuilder
    private var calendarAuthContent: some View {
        switch calendar.authorizationStatus {
        case .notDetermined:
            HStack {
                Label("Calendar", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                Spacer()
            }
            Text("Connect macOS Calendar to sync Google, iCloud, and Exchange/Teams.")
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                calendar.requestAccess()
            } label: {
                Text("Connect")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchColors.notchBackground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(NotchColors.accentPrimary))
            }
            .buttonStyle(.plain)

        case .denied, .restricted:
            Label("Calendar", systemImage: "calendar.badge.exclamationmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchColors.textPrimary)
            Text("Calendar access denied in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                calendar.openCalendarPrivacySettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.accentPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))

        default:
            EmptyView()
        }
    }

    private var calendarCard: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                if calendarNeedsAuth {
                    calendarAuthContent
                } else {
                    upcomingEventsContent
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingEventsContent: some View {
        if let nextEvent = calendar.upcomingEvents.first {
            let countdown = CalendarLogic.formatCountdown(
                from: calendar.now,
                to: nextEvent.startDate,
                end: nextEvent.endDate
            )
            let badgeColor = countdown == "Now"
                ? NotchColors.statusHealthy
                : (nextEvent.startDate.timeIntervalSince(calendar.now) <= 15 * 60
                    ? NotchColors.statusWarning
                    : NotchColors.accentPrimary)

            HStack(spacing: 6) {
                Label("Calendar", systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textSecondary)
                Spacer()
                Text(countdown)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(badgeColor.opacity(0.16)))
                Button {
                    manager.setHomeSubView(.calendar)
                } label: {
                    Text("Month")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                .accessibilityLabel("Open Calendar view")
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextEvent.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                        .lineLimit(1)
                    Text(nextEventSubtitle(for: nextEvent))
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let meetingURL = nextEvent.meetingURL {
                    Button {
                        calendar.openMeeting(meetingURL)
                    } label: {
                        Text("Join")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotchColors.notchBackground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7).fill(NotchColors.accentPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            if calendar.upcomingEvents.count > 1 {
                let second = calendar.upcomingEvents[1]
                Text("Next: \(second.timeRangeText) • \(second.title)")
                    .font(.system(size: 10))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        } else {
            Label("Calendar", systemImage: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchColors.textPrimary)
            Text("No upcoming events in the next 7 days.")
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                calendar.refreshEvents()
            } label: {
                Text("Refresh")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchColors.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
        }
    }

    private func nextEventSubtitle(for event: CalendarEventItem) -> String {
        if let provider = event.meetingProvider {
            return "\(event.timeRangeText) • \(provider)"
        }
        return event.timeRangeText
    }

    private var pomodoroTile: some View {
        Button {
            productivity.togglePomodoro()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: productivity.pomodoro.isRunning ? "pause.fill" : "timer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchColors.focusAccent)
                Text(productivity.pomodoro.formattedTime)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(NotchColors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NotchColors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 10))
        .accessibilityLabel(productivity.pomodoro.isRunning ? "Pause Pomodoro" : "Start Pomodoro")
    }

    private func wingTile(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(NotchColors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NotchColors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 10))
    }
}

// MARK: - 2. Files Smart Tray Tab

struct FilesTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var filesTray: FilesTrayService

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Files Smart Tray", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    if !filesTray.items.isEmpty {
                        Button("Clear All") {
                            filesTray.clearAll()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchColors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                    }
                    Button {
                        manager.setPresentingFilePicker(true)
                        filesTray.pickFilesFromPanel { count in
                            manager.setPresentingFilePicker(false)
                            if count > 0 {
                                manager.showToast(count == 1 ? "Added 1 file" : "Added \(count) files")
                            }
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(NotchColors.accentPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                }

                if filesTray.items.isEmpty {
                    Button {
                        manager.setPresentingFilePicker(true)
                        filesTray.pickFilesFromPanel { count in
                            manager.setPresentingFilePicker(false)
                            if count > 0 {
                                manager.showToast(count == 1 ? "Added 1 file" : "Added \(count) files")
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(NotchColors.textPrimary)
                            Text("Drop files onto notch")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NotchColors.textPrimary)
                            Text("Click to browse · Drag out anytime · AirDrop · Compress · OCR")
                                .font(.system(size: 10.5))
                                .foregroundStyle(NotchColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(NotchColors.controlSubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11)
                                        .strokeBorder(
                                            NotchColors.controlBorder.opacity(0.75),
                                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(filesTray.items) { item in
                                fileTile(item)
                            }
                        }
                    }

                    if let selected = filesTray.selectedItem {
                        HStack(spacing: 6) {
                            Text(selected.name)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(NotchColors.textSecondary)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if filesTray.isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Button("AirDrop") {
                                manager.showToast(filesTray.shareViaAirDrop(selected))
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(NotchColors.accentPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                            Button("Compress") {
                                Task {
                                    let message = await filesTray.compress(selected)
                                    manager.showToast(message)
                                }
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(selected.supportsCompression ? NotchColors.textPrimary : NotchColors.textSecondary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .disabled(!selected.supportsCompression || filesTray.isProcessing)

                            Button("OCR") {
                                Task {
                                    let result = await filesTray.extractOCRText(selected)
                                    switch result {
                                    case .success:
                                        manager.showToast("OCR text copied to clipboard")
                                    case .failure(let error):
                                        manager.showToast(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(selected.supportsOCR ? NotchColors.textPrimary : NotchColors.textSecondary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .disabled(!selected.supportsOCR || filesTray.isProcessing)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func fileTile(_ item: StagedFileItem) -> some View {
        let isSelected = filesTray.selectedItem?.id == item.id
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(item.kind.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(NotchColors.notchBackground)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(NotchColors.accentPrimary))

                Spacer(minLength: 2)

                Button {
                    filesTray.remove(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 4))
                .accessibilityLabel("Remove \(item.name)")
            }

            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchColors.textPrimary)
                .lineLimit(1)

            Text(item.formattedSize)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(NotchColors.textSecondary)
                .lineLimit(1)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? NotchColors.controlSelected : NotchColors.controlSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? NotchColors.accentPrimary : NotchColors.cardBorder, lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            filesTray.selectedID = item.id
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}

// MARK: - 3. Focus Tab (Warm Amber Pomodoro + Switchable To-do / Quick Notes)

private enum FocusRightPane {
    case todo
    case notes
}

struct NotesTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var obsidian: ObsidianService
    @ObservedObject var productivity: ProductivityService

    @State private var rightPane: FocusRightPane = .todo
    @State private var noteDraft = ""
    @State private var selectedTags: [String] = []
    @State private var isEditingNote = false
    @FocusState private var isNoteFieldFocused: Bool

    @State private var isAddingTodo = false
    @State private var newTodoText = ""
    @FocusState private var isTodoFieldFocused: Bool

    @State private var isEditingTimer = false
    @State private var timerMinutesDraft = ""
    @State private var dragBaseMinutes: Int?
    @FocusState private var isTimerFieldFocused: Bool

    private let quickTags = ["#floqy", "#idea", "#dev"]

    private static let finishTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 10) {
            focusTimerCard
            todoAndNotesCard
        }
        .onDisappear {
            if isAddingTodo {
                cancelNewTodo()
            }
            if isEditingTimer {
                cancelTimerEdit()
            }
            if isEditingNote {
                endNoteEdit()
            }
        }
    }

    private var focusTimerCard: some View {
        let elapsedFraction = max(0.0, min(1.0, 1.0 - productivity.pomodoro.remainingProgress))
        let finishDate = Date().addingTimeInterval(TimeInterval(productivity.pomodoro.remainingSeconds))
        let currentRound = productivity.currentRoundNumber

        return NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus · Session \(currentRound) of 4")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(NotchColors.textSecondary)

                        timerDisplayControl

                        HStack(spacing: 4) {
                            Text(Self.finishTimeFormatter.string(from: finishDate))
                                .foregroundStyle(NotchColors.textSecondary)
                            Text("until done")
                                .fontWeight(.semibold)
                                .foregroundStyle(NotchColors.focusAccent)
                        }
                        .font(.system(size: 10.5))
                        .monospacedDigit()
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Button(productivity.pomodoro.isRunning ? "Pause" : "Start") {
                            if isEditingTimer {
                                commitTimerEdit()
                            }
                            productivity.togglePomodoro()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchColors.focusAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)

                        Button {
                            if isEditingTimer {
                                cancelTimerEdit()
                            }
                            productivity.resetPomodoro()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NotchColors.textSecondary)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .accessibilityLabel("Reset Focus Timer")
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    ForEach(1...4, id: \.self) { step in
                        roundNode(label: "\(step)", isDone: step < currentRound, isActive: step == currentRound)
                        Spacer()
                    }
                    roundNode(label: "Long", isDone: false, isActive: false)
                }
                .padding(.horizontal, 4)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(NotchColors.trackBackground)
                        Capsule()
                            .fill(NotchColors.focusAccent)
                            .frame(width: max(4, geo.size.width * elapsedFraction))
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func roundNode(label: String, isDone: Bool, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isDone ? NotchColors.focusAccent : (isActive ? NotchColors.textPrimary : NotchColors.controlBorder.opacity(0.75)))
                .frame(width: isActive ? 9 : 7, height: isActive ? 9 : 7)
                .overlay(
                    Circle()
                        .stroke(isActive ? NotchColors.focusAccent : Color.clear, lineWidth: 2)
                )
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(NotchColors.textSecondary)
        }
    }

    private var todoAndNotesCard: some View {
        let doneCount = productivity.todos.filter(\.isDone).count

        return NotchCard {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        paneSwitchButton("To-do (\(doneCount)/\(productivity.todos.count))", pane: .todo)
                        paneSwitchButton("Notes", pane: .notes)
                    }
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 7).fill(NotchColors.controlSurface))

                    Spacer(minLength: 4)

                    if rightPane == .todo {
                        if !isAddingTodo {
                            Button {
                                if isEditingTimer { cancelTimerEdit() }
                                if isEditingNote { endNoteEdit() }
                                isAddingTodo = true
                                manager.beginTextInput()
                                isTodoFieldFocused = true
                            } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(NotchColors.textPrimary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        }
                    } else {
                        notesFolderMenus
                    }
                }

                if rightPane == .todo {
                    todoListContent
                } else {
                    quickNotesContent
                }
            }
        }
    }

    private func paneSwitchButton(_ title: String, pane: FocusRightPane) -> some View {
        let isSelected = rightPane == pane
        return Button {
            if pane == .todo && isEditingNote {
                endNoteEdit()
            } else if pane == .notes && isAddingTodo {
                cancelNewTodo()
            }
            rightPane = pane
        } label: {
            Text(title)
                .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? NotchColors.textPrimary : NotchColors.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? NotchColors.controlSelected : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var todoListContent: some View {
        if isAddingTodo {
            HStack(spacing: 5) {
                TextField("New task…", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchColors.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(NotchColors.controlSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(NotchColors.accentPrimary, lineWidth: 1)
                            )
                    )
                    .focused($isTodoFieldFocused)
                    .onSubmit {
                        commitNewTodo()
                    }

                Button {
                    cancelNewTodo()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                .accessibilityLabel("Cancel new task")
            }
        }

        if productivity.todos.isEmpty {
            Text("No tasks yet.")
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(productivity.todos) { item in
                        HStack(spacing: 7) {
                            Button {
                                productivity.toggleTodo(id: item.id)
                            } label: {
                                HStack(spacing: 7) {
                                    ZStack {
                                        Circle()
                                            .stroke(
                                                item.isDone ? NotchColors.statusHealthy : NotchColors.controlBorder,
                                                lineWidth: 1.5
                                            )
                                            .background(
                                                Circle().fill(item.isDone ? NotchColors.statusHealthy : Color.clear)
                                            )
                                        if item.isDone {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(NotchColors.notchBackground)
                                        }
                                    }
                                    .frame(width: 14, height: 14)

                                    Text(item.title)
                                        .font(.system(size: 11))
                                        .strikethrough(item.isDone)
                                        .foregroundStyle(item.isDone ? NotchColors.textSecondary : NotchColors.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isDone ? "Mark \(item.title) incomplete" : "Mark \(item.title) complete")

                            Spacer(minLength: 2)

                            Button {
                                productivity.deleteTodo(id: item.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(NotchColors.textSecondary)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 4))
                            .accessibilityLabel("Delete \(item.title)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.isDone ? NotchColors.statusHealthy.opacity(0.14) : NotchColors.controlSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            item.isDone ? NotchColors.statusHealthy.opacity(0.24) : NotchColors.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                }
            }
        }
    }

    private var notesFolderMenus: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(ObsidianNoteTarget.allCases) { target in
                    Button(target.rawValue) {
                        obsidian.target = target
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(obsidian.target.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(NotchColors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(NotchColors.controlSurface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(NotchColors.cardBorder, lineWidth: 1))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                Button("Open Folder") {
                    obsidian.openActiveNotesFolder()
                }
                Button("Choose Folder…") {
                    if isEditingNote {
                        endNoteEdit()
                    }
                    manager.setPresentingFilePicker(true)
                    obsidian.chooseVaultFolder {
                        manager.setPresentingFilePicker(false)
                    }
                }
                if obsidian.isVaultConfigured {
                    Divider()
                    Button("Use Default Folder") {
                        obsidian.disconnectVault()
                    }
                }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchColors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(NotchColors.controlSurface)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(NotchColors.cardBorder, lineWidth: 1))
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Notes folder options")
            .help("Notes folder: \(obsidian.storageLabel)")
        }
    }

    @ViewBuilder
    private var quickNotesContent: some View {
        if isEditingNote {
            TextField("Write a quick note…", text: $noteDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(NotchColors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NotchColors.controlSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NotchColors.accentPrimary, lineWidth: 1)
                        )
                )
                .focused($isNoteFieldFocused)
                .onSubmit {
                    appendObsidianNote()
                }
                .onKeyPress(.escape) {
                    endNoteEdit()
                    return .handled
                }
        } else {
            Button {
                beginNoteEdit()
            } label: {
                Text(noteDraft.isEmpty ? "Click to write a note for \(obsidian.target.rawValue)…" : noteDraft)
                    .font(.system(size: 11))
                    .foregroundStyle(noteDraft.isEmpty ? NotchColors.textSecondary : NotchColors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(NotchColors.controlSubtle)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(NotchColors.cardBorder, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }

        HStack(spacing: 4) {
            ForEach(quickTags, id: \.self) { tag in
                let isActive = selectedTags.contains(tag)
                Button(tag) {
                    toggleTag(tag)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5, isSelected: isActive))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive ? NotchColors.textPrimary : NotchColors.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
            }

            Spacer(minLength: 4)

            Button("Save") {
                appendObsidianNote()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(NotchColors.notchBackground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(NotchColors.accentPrimary))
        }

        if let error = obsidian.lastError {
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(NotchColors.statusAlert)
                .lineLimit(1)
        } else if let saved = obsidian.lastSavedSummary {
            Text(saved)
                .font(.system(size: 10))
                .foregroundStyle(NotchColors.statusHealthy)
                .lineLimit(1)
        } else if let latest = obsidian.recentNotes.first {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(latest, forType: .string)
                manager.showToast("Copied latest note")
            } label: {
                Text(latest)
                    .font(.system(size: 10))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help("Click to copy latest note")
        }
    }

    @ViewBuilder
    private var timerDisplayControl: some View {
        if isEditingTimer {
            HStack(spacing: 4) {
                TextField("25", text: $timerMinutesDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(NotchColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 54)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(NotchColors.controlSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(NotchColors.focusAccent, lineWidth: 1)
                            )
                    )
                    .focused($isTimerFieldFocused)
                    .onSubmit {
                        commitTimerEdit()
                    }
                    .onKeyPress(.escape) {
                        cancelTimerEdit()
                        return .handled
                    }

                Text("min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textSecondary)
            }
        } else if !productivity.pomodoro.isRunning {
            Button {
                startTimerEdit()
            } label: {
                Text(productivity.pomodoro.formattedTime)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(NotchColors.textPrimary)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let base = dragBaseMinutes ?? productivity.pomodoro.durationMinutes
                        if dragBaseMinutes == nil {
                            dragBaseMinutes = base
                        }
                        let deltaMinutes = -Int(value.translation.height / 6)
                        productivity.setPomodoroDuration(minutes: base + deltaMinutes)
                    }
                    .onEnded { _ in
                        dragBaseMinutes = nil
                    }
            )
            .accessibilityLabel("Adjust focus duration, \(productivity.pomodoro.durationMinutes) minutes")
            .help("Click to type minutes or drag up/down to adjust")
        } else {
            Text(productivity.pomodoro.formattedTime)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(NotchColors.focusAccent)
        }
    }

    private func beginNoteEdit() {
        if isAddingTodo { cancelNewTodo() }
        if isEditingTimer { cancelTimerEdit() }
        obsidian.clearTransientFeedback()
        isEditingNote = true
        manager.beginTextInput()
        isNoteFieldFocused = true
    }

    private func endNoteEdit() {
        isEditingNote = false
        isNoteFieldFocused = false
        manager.endTextInput()
    }

    private func toggleTag(_ tag: String) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    private func appendObsidianNote() {
        let body = noteDraft
        let tags = selectedTags
        guard obsidian.appendNote(body: body, tags: tags) else { return }
        // Resign key focus before clearing bindings so AppKit's field editor never writes the old text back.
        endNoteEdit()
        noteDraft = ""
        selectedTags.removeAll()
        manager.showToast("Saved to \(obsidian.isVaultConfigured ? obsidian.storageLabel : "Notes")")
    }

    private func startTimerEdit() {
        if isAddingTodo { cancelNewTodo() }
        if isEditingNote { endNoteEdit() }
        timerMinutesDraft = "\(productivity.pomodoro.durationMinutes)"
        isEditingTimer = true
        manager.beginTextInput()
        isTimerFieldFocused = true
    }

    private func commitTimerEdit() {
        if let minutes = Int(timerMinutesDraft.trimmingCharacters(in: .whitespaces)) {
            productivity.setPomodoroDuration(minutes: minutes)
        }
        isEditingTimer = false
        isTimerFieldFocused = false
        manager.endTextInput()
    }

    private func cancelTimerEdit() {
        timerMinutesDraft = ""
        isEditingTimer = false
        isTimerFieldFocused = false
        manager.endTextInput()
    }

    private func commitNewTodo() {
        let title = newTodoText
        isAddingTodo = false
        isTodoFieldFocused = false
        manager.endTextInput()
        newTodoText = ""
        productivity.addTodo(title)
    }

    private func cancelNewTodo() {
        newTodoText = ""
        isAddingTodo = false
        isTodoFieldFocused = false
        manager.endTextInput()
    }
}

// MARK: - 4. Copy (Clipboard Manager) Tab

struct ClipboardTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var clipboard: ClipboardService

    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if isSearching || !clipboard.searchQuery.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10.5))
                                .foregroundStyle(NotchColors.textSecondary)

                            TextField("Search clipboard…", text: $clipboard.searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(NotchColors.textPrimary)
                                .focused($isSearchFieldFocused)
                                .onKeyPress(.escape) {
                                    stopSearch(clearQuery: true)
                                    return .handled
                                }

                            Button {
                                stopSearch(clearQuery: true)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(NotchColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(NotchColors.controlSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(isSearching ? NotchColors.accentPrimary : NotchColors.cardBorder, lineWidth: 1)
                                )
                        )
                    } else {
                        Button {
                            startSearch()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10.5))
                                Text("Search clipboard…")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(NotchColors.controlSubtle)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(NotchColors.cardBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("⌘⇧V")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(NotchColors.textSecondary)

                    if clipboard.hasUnpinnedEntries {
                        Button("Clear") {
                            clipboard.clearUnpinned()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchColors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                    }
                }

                let visibleEntries = clipboard.filteredEntries
                if visibleEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clipboard.entries.isEmpty ? "Clipboard history is empty." : "No matching items.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(NotchColors.textPrimary)
                        Text(clipboard.entries.isEmpty ? "Copy text, code, links, or images anywhere on your Mac to capture them here." : "Try a different search term.")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(visibleEntries) { entry in
                                clipboardRow(entry)
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            if isSearching {
                stopSearch(clearQuery: false)
            }
        }
    }

    private func clipboardRow(_ entry: ClipboardEntry) -> some View {
        HStack(spacing: 8) {
            Button {
                clipboard.copyToPasteboard(entry)
                manager.showToast("Copied to clipboard")
            } label: {
                HStack(spacing: 7) {
                    Text(entry.kind.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(NotchColors.accentForeground)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(NotchColors.accentPrimary))

                    if let data = entry.imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(entry.textContent.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 11, design: entry.kind == .code ? .monospaced : .default))
                        .foregroundStyle(NotchColors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                clipboard.togglePin(entry.id)
            } label: {
                Image(systemName: entry.isPinned ? "star.fill" : "star")
                    .font(.system(size: 10.5))
                    .foregroundStyle(entry.isPinned ? NotchColors.statusWarning : NotchColors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
            .accessibilityLabel(entry.isPinned ? "Unpin clipboard item" : "Pin clipboard item")

            Button {
                clipboard.delete(entry.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(NotchColors.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
            .accessibilityLabel("Delete clipboard item")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(NotchColors.controlSubtle)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NotchColors.cardBorder, lineWidth: 1))
        )
    }

    private func startSearch() {
        isSearching = true
        manager.beginTextInput()
        isSearchFieldFocused = true
    }

    private func stopSearch(clearQuery: Bool) {
        if clearQuery {
            clipboard.searchQuery = ""
        }
        isSearching = false
        isSearchFieldFocused = false
        manager.endTextInput()
    }
}

// MARK: - 5. AI Agent Tab

struct AITabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var ai: AIService

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 10) {
            activityCard
            agentsCard
        }
        .onAppear {
            ai.refreshHookStatus()
            ai.refreshClaudeLocalUsage()
        }
    }

    private var activityCard: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Label("AI Activity", systemImage: "command")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)

                    Spacer(minLength: 4)

                    Text(ai.workingAgent.map { "\($0.shortName) Working" } ?? "Idle")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ai.workingAgent != nil ? NotchColors.accentPrimary : NotchColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                ai.workingAgent != nil
                                    ? NotchColors.accentPrimary.opacity(0.16)
                                    : NotchColors.controlSurface
                            )
                        )
                }

                HStack(spacing: 5) {
                    counterTile(title: "Antigravity", count: ai.todayCount(for: .antigravity))
                    counterTile(title: "Gemini", count: ai.todayCount(for: .geminiCLI))
                    counterTile(title: "Claude", count: ai.todayCount(for: .claudeCode))
                }

                if let usage = ai.claudeUsageToday {
                    HStack {
                        Text("Claude Code today")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(NotchColors.statusWarning)
                        Spacer()
                        Text("\(LocalTokenUsageSummary.formatTokens(usage.totalTokens)) tok • \(LocalTokenUsageSummary.formatUSD(usage.estimatedCostUSD))")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NotchColors.statusWarning)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(NotchColors.statusWarning.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(NotchColors.statusWarning.opacity(0.25), lineWidth: 1))
                    )
                }

                Divider().overlay(NotchColors.cardBorder)

                if ai.recentCompletions.isEmpty {
                    Text("Connect a hook to receive completion alerts.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(ai.recentCompletions) { record in
                                HStack(spacing: 6) {
                                    Text(record.agent.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(accentColor(for: record.agent))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(accentColor(for: record.agent).opacity(0.14)))

                                    Text(Self.timeFormatter.string(from: record.completedAt))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(NotchColors.textSecondary)

                                    Spacer(minLength: 4)

                                    Button("Open") {
                                        ai.openAgentApp(record.agent)
                                    }
                                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(NotchColors.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var agentsCard: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Agents", systemImage: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    Text("Hooks")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchColors.textSecondary)
                }

                Divider().overlay(NotchColors.cardBorder)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(AIAgentKind.allCases) { agent in
                            agentRow(agent)
                        }
                    }
                }
            }
        }
    }

    private func agentRow(_ agent: AIAgentKind) -> some View {
        let isConnected = ai.hookStatus[agent] == true

        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.displayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text(agent.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if agent.supportsHook {
                Button(isConnected ? "Connected" : "Connect") {
                    let message = ai.toggleHook(for: agent)
                    manager.showToast(message)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isConnected ? NotchColors.statusHealthy : NotchColors.accentPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill((isConnected ? NotchColors.statusHealthy : NotchColors.accentPrimary).opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke((isConnected ? NotchColors.statusHealthy : NotchColors.accentPrimary).opacity(0.35), lineWidth: 1)
                        )
                )
            }

            Button("Open") {
                ai.openAgentApp(agent)
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(NotchColors.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
    }

    private func counterTile(title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(NotchColors.textSecondary)
                .lineLimit(1)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(NotchColors.textPrimary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(NotchColors.controlSubtle)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(NotchColors.cardBorder, lineWidth: 1))
        )
    }

    private func accentColor(for agent: AIAgentKind) -> Color {
        switch agent {
        case .antigravity: return NotchColors.accentPrimary
        case .geminiCLI: return NotchColors.statusHealthy
        case .claudeCode, .claudeDesktop: return NotchColors.statusWarning
        }
    }
}

// MARK: - 6. System Tab (Memory Monitor + Dev Live Activity)

struct SystemTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var system: SystemMonitorService

    var body: some View {
        HStack(spacing: 10) {
            memoryCard
            devAndPortsCard
        }
        .onAppear {
            system.setSystemTabVisible(true)
        }
        .onDisappear {
            system.setSystemTabVisible(false)
        }
    }

    private var memoryCard: some View {
        let snap = system.snapshot
        let levelColor = pressureColor(snap.pressureLevel)

        return NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Label("Memory", systemImage: "memorychip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)

                    Text("\(snap.usedPercent)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(levelColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(levelColor.opacity(0.16)))

                    Spacer(minLength: 4)

                    Button(system.isPurging ? "Purging…" : "Purge") {
                        Task {
                            let message = await system.purgeMemoryCache()
                            manager.showToast(message)
                        }
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchColors.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .disabled(system.isPurging)
                }

                memoryBar(snap)

                Text(
                    "App \(MemorySnapshot.formatBytes(snap.appBytes)) • Wired \(MemorySnapshot.formatBytes(snap.wiredBytes)) • Comp \(MemorySnapshot.formatBytes(snap.compressedBytes)) • Swap \(MemorySnapshot.formatBytes(snap.swapUsedBytes))"
                )
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(NotchColors.textSecondary)
                .lineLimit(1)

                Divider().overlay(NotchColors.cardBorder)

                if system.topConsumers.isEmpty {
                    Text("Scanning memory consumers…")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(system.topConsumers) { consumer in
                                HStack(spacing: 6) {
                                    Text(consumer.name)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(NotchColors.textPrimary)
                                        .lineLimit(1)

                                    Spacer(minLength: 4)

                                    Text(MemorySnapshot.formatBytes(consumer.residentBytes))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(NotchColors.textSecondary)

                                    Button {
                                        if system.terminateProcess(pid: consumer.pid, name: consumer.name) {
                                            manager.showToast("Sent quit to \(consumer.name)")
                                        } else if let msg = system.statusMessage {
                                            manager.showToast(msg)
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8.5, weight: .semibold))
                                            .foregroundStyle(NotchColors.textSecondary)
                                            .frame(width: 18, height: 18)
                                    }
                                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 4))
                                    .accessibilityLabel("Quit \(consumer.name)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func memoryBar(_ snap: MemorySnapshot) -> some View {
        let total = max(1.0, Double(snap.totalBytes))
        let appFrac = min(1.0, Double(snap.appBytes) / total)
        let wiredFrac = min(max(0.0, 1.0 - appFrac), Double(snap.wiredBytes) / total)
        let compFrac = min(max(0.0, 1.0 - appFrac - wiredFrac), Double(snap.compressedBytes) / total)

        return GeometryReader { proxy in
            HStack(spacing: 1) {
                Rectangle()
                    .fill(NotchColors.accentPrimary)
                    .frame(width: max(0, proxy.size.width * appFrac))
                Rectangle()
                    .fill(NotchColors.statusWarning)
                    .frame(width: max(0, proxy.size.width * wiredFrac))
                Rectangle()
                    .fill(NotchColors.statusAlert)
                    .frame(width: max(0, proxy.size.width * compFrac))
                Spacer(minLength: 0)
            }
            .background(NotchColors.controlSurface)
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }

    private var devAndPortsCard: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Label("Local Ports", systemImage: "network")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)

                    Spacer(minLength: 4)

                    Button {
                        system.refreshProcessesAndPorts()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel("Refresh ports and processes")
                }

                Divider().overlay(NotchColors.cardBorder)

                if system.localPorts.isEmpty {
                    Text("No active local dev ports.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(system.localPorts) { port in
                                HStack(spacing: 6) {
                                    Text(verbatim: ":\(port.port)")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(NotchColors.accentPrimary)

                                    Text(port.processName)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(NotchColors.textSecondary)
                                        .lineLimit(1)

                                    Spacer(minLength: 4)

                                    if port.isHTTP {
                                        Button("Open") {
                                            system.openLocalPort(port)
                                        }
                                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(NotchColors.textPrimary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                    }

                                    Button {
                                        if system.terminateProcess(pid: port.pid, name: port.processName) {
                                            manager.showToast("Stopped :\(String(port.port))")
                                        } else if let msg = system.statusMessage {
                                            manager.showToast(msg)
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8.5, weight: .semibold))
                                            .foregroundStyle(NotchColors.textSecondary)
                                            .frame(width: 18, height: 18)
                                    }
                                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 4))
                                    .accessibilityLabel("Stop \(port.processName) on port \(String(port.port))")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .nominal: return NotchColors.statusHealthy
        case .warning: return NotchColors.statusWarning
        case .critical: return NotchColors.statusAlert
        }
    }
}

// MARK: - 7. Inline Settings Tab (Gear Button Beside System)

struct InlineSettingsTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        HStack(spacing: 10) {
            NotchCard {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Appearance & Idle")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)

                    HStack(spacing: 8) {
                        Text("Theme")
                            .font(.system(size: 11.5))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer(minLength: 8)
                        Button {
                            NotchPopupMenu.show(
                                items: NotchThemePreset.allCases.map { ($0.title, $0) },
                                selected: manager.themePreset
                            ) { chosen in
                                manager.themePreset = chosen
                            }
                        } label: {
                            settingsDropdownLabel(manager.themePreset.title)
                        }
                        .buttonStyle(.plain)
                    }

                    if manager.themePreset.usesWallpaper {
                        HStack(spacing: 6) {
                            Text("Wallpaper")
                                .font(.system(size: 11.5))
                                .foregroundStyle(NotchColors.textPrimary)
                            Spacer(minLength: 6)
                            Button("Choose…") {
                                manager.chooseWallpaperImage()
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)

                            if manager.wallpaperImage != nil {
                                Button("Clear") {
                                    manager.clearWallpaperImage()
                                }
                                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(NotchColors.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("Idle width")
                                .font(.system(size: 11.5))
                                .foregroundStyle(NotchColors.textPrimary)
                            Spacer(minLength: 8)
                            HStack(spacing: 2) {
                                ForEach(IdleNotchWidth.allCases) { widthOption in
                                    let selected = manager.idleWidth == widthOption
                                    Button {
                                        manager.idleWidth = widthOption
                                    } label: {
                                        Text(widthOption.title)
                                            .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                                            .foregroundStyle(selected ? NotchColors.textPrimary : NotchColors.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                                    .fill(selected ? NotchColors.statusHealthy.opacity(0.24) : Color.clear)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                                    .strokeBorder(
                                                        selected ? NotchColors.statusHealthy.opacity(0.75) : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(NotchColors.controlSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(NotchColors.cardBorder, lineWidth: 1)
                            )
                            .opacity(manager.idleAppearance.usesBottomChin ? 1 : 0.4)
                            .disabled(!manager.idleAppearance.usesBottomChin)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Idle notch")
                            .font(.system(size: 11.5))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer(minLength: 8)
                        Button {
                            NotchPopupMenu.show(
                                items: IdleAppearance.allCases.map { ($0.title, $0) },
                                selected: manager.idleAppearance
                            ) { chosen in
                                manager.idleAppearance = chosen
                            }
                        } label: {
                            settingsDropdownLabel(manager.idleAppearance.title)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Text("Calendar & Notes")
                            .font(.system(size: 10.5))
                            .foregroundStyle(NotchColors.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Button("All Settings…") {
                            manager.onOpenFullSettings?()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }

            NotchCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cards & Alerts")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)

                    toggleRow("Headphones connected card", isOn: $manager.headphonesCardEnabled)
                    toggleRow("Charging status card", isOn: $manager.chargingCardEnabled)
                    toggleRow("Auto-expand on hover", isOn: $manager.hoverToExpandEnabled)
                    toggleRow("Notification sounds", isOn: $manager.alertSoundsEnabled)
                    toggleRow("RAM ≥ \(SystemLogic.ramAlertThresholdPercent)% alert", isOn: $manager.ramAlertEnabled)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func settingsDropdownLabel(_ title: String) -> some View {
        let palette = NotchColors.palette(for: manager.effectiveThemePreset)
        return HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .foregroundStyle(palette.textPrimary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(palette.controlSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(palette.controlBorder.opacity(0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(NotchSwitchToggleStyle())
            .font(.system(size: 11.5))
            .foregroundStyle(NotchColors.textPrimary)
    }
}
