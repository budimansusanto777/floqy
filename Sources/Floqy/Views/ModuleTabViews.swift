import EventKit
import SwiftUI

/// Shared card container with verified dark surface and border contrast.
struct NotchCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(NotchColors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(NotchColors.cardBorder, lineWidth: 1)
                    )
            )
    }
}

private struct PhaseBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(NotchColors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(NotchColors.cardBorder, lineWidth: 1))
            )
    }
}

// MARK: - 1. Home Tab (Music + Calendar + Pomodoro/Todo Strip)

struct HomeTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var music: MusicService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var productivity: ProductivityService

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
                        title: "System",
                        icon: "cpu",
                        color: NotchColors.statusWarning
                    ) {
                        manager.selectTab(.system)
                    }
                }
                .frame(height: 38)
            }
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
                    ScrollView {
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
                .fill(Color.white.opacity(0.04))
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
                                    .fill(Color.white.opacity(0.14))
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
                .fill(Color.white.opacity(0.08))
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
                    .foregroundStyle(NotchColors.statusAlert)
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

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Files Smart Tray", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    if !manager.droppedFileNames.isEmpty {
                        Button("Clear All") {
                            manager.clearDroppedFiles()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchColors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                    }
                    PhaseBadge(label: "Phase 2")
                }

                if manager.droppedFileNames.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tray is empty.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(NotchColors.textPrimary)
                        Text("Drag any file from Finder onto the notch to stage it here. Native AirDrop, compression, and OCR arrive in Phase 2.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(NotchColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(Array(manager.droppedFileNames.enumerated()), id: \.offset) { index, name in
                                HStack {
                                    Image(systemName: "doc")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(NotchColors.accentPrimary)
                                    Text(name)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(NotchColors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        manager.removeDroppedFile(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(NotchColors.textSecondary)
                                            .frame(width: 18, height: 18)
                                    }
                                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                                    .accessibilityLabel("Remove \(name)")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(NotchColors.cardBorder, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }

                    Text("AirDrop, WebP compression, and offline OCR actions unlock in Phase 2.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - 3. Notes & Todo Tab

struct NotesTabView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var productivity: ProductivityService

    @State private var isAddingTodo = false
    @State private var newTodoText = ""
    @FocusState private var isTodoFieldFocused: Bool

    @State private var isEditingTimer = false
    @State private var timerMinutesDraft = ""
    @State private var dragBaseMinutes: Int?
    @FocusState private var isTimerFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Obsidian Quick Note", systemImage: "note.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 2")
                    }
                    Text("Append quick thoughts and tags straight into your security-scoped Obsidian Vault.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }

            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        timerDisplayControl

                        Spacer()

                        Button(productivity.pomodoro.isRunning ? "Pause" : "Start") {
                            if isEditingTimer {
                                commitTimerEdit()
                            }
                            productivity.togglePomodoro()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchColors.statusAlert)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)

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

                    Divider().overlay(NotchColors.cardBorder)

                    if productivity.todos.isEmpty {
                        Text("No tasks yet.")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(productivity.todos) { item in
                                    HStack(spacing: 6) {
                                        Button {
                                            productivity.toggleTodo(id: item.id)
                                        } label: {
                                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 12))
                                                .foregroundStyle(
                                                    item.isDone ? NotchColors.statusHealthy : NotchColors.textSecondary
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(item.isDone ? "Mark \(item.title) incomplete" : "Mark \(item.title) complete")

                                        Text(item.title)
                                            .font(.system(size: 11))
                                            .strikethrough(item.isDone)
                                            .foregroundStyle(item.isDone ? NotchColors.textSecondary : NotchColors.textPrimary)
                                            .lineLimit(1)

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
                                }
                            }
                        }
                    }

                    if isAddingTodo {
                        HStack(spacing: 5) {
                            TextField("New task…", text: $newTodoText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(NotchColors.textPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
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
                    } else {
                        Button {
                            if isEditingTimer {
                                cancelTimerEdit()
                            }
                            isAddingTodo = true
                            manager.beginTextInput()
                            isTodoFieldFocused = true
                        } label: {
                            Label("Add todo", systemImage: "plus")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(NotchColors.accentPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                    }
                }
            }
        }
        .onDisappear {
            if isAddingTodo {
                cancelNewTodo()
            }
            if isEditingTimer {
                cancelTimerEdit()
            }
        }
    }

    @ViewBuilder
    private var timerDisplayControl: some View {
        if isEditingTimer {
            HStack(spacing: 4) {
                TextField("25", text: $timerMinutesDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(NotchColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(NotchColors.accentPrimary, lineWidth: 1)
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
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchColors.textSecondary)
            }
        } else if !productivity.pomodoro.isRunning {
            Button {
                startTimerEdit()
            } label: {
                Text(productivity.pomodoro.formattedTime)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(NotchColors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(NotchColors.statusAlert)
        }
    }

    private func startTimerEdit() {
        if isAddingTodo {
            cancelNewTodo()
        }
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
        productivity.addTodo(newTodoText)
        newTodoText = ""
        isAddingTodo = false
        isTodoFieldFocused = false
        manager.endTextInput()
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

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Copy Windows — Clipboard History", systemImage: "doc.on.clipboard")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    Text("⌘⇧V")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(NotchColors.textSecondary)
                    PhaseBadge(label: "Phase 2")
                }
                Text("Lightweight NSPasteboard watcher with auto-type badges (Code, URL, Text, Image), search, pinning, and 1-click AI explanation.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - 5. AI Agent Tab

struct AITabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "command")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.accentPrimary)
                    Text("Floqy AI Agent")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    PhaseBadge(label: "Phase 4")
                }

                Text("BYOK (Gemini, OpenAI, Claude) and local Ollama support with Keychain storage, cross-module context, and background notch execution.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Button {
                    manager.showCompact(.ai)
                } label: {
                    Label("Preview AI Wing", systemImage: "command")
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

// MARK: - 6. System Tab (Memory Monitor + Dev Live Activity)

struct SystemTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        HStack(spacing: 10) {
            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Memory Pressure", systemImage: "memorychip")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 3")
                    }
                    Text("Kernel RAM stats (App, Wired, Compressed, Swap), top consumers with 1-click Kill, and Purge.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        manager.showCompact(.memory)
                    } label: {
                        Label("Preview RAM Wing", systemImage: "memorychip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchColors.statusWarning)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                }
            }

            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Dev Live Activity & Ports", systemImage: "hammer.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 3")
                    }
                    Text("Active local port scanner (:3000, :5173, :5432) and companion `floqy` CLI build updates.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        manager.showCompact(.dev)
                    } label: {
                        Label("Preview Build Wing", systemImage: "hammer.fill")
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
}
