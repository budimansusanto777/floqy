import SwiftUI

/// Compact Live Activity wings displayed on either side of the hardware camera notch.
struct NotchCompactView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var music: MusicService
    @ObservedObject var productivity: ProductivityService
    @ObservedObject var system: SystemMonitorService
    let activity: CompactActivity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringMusicControls = false

    var body: some View {
        HStack(spacing: 0) {
            leftWing
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: manager.geometry.notchCenterGapWidth)

            rightWing
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            manager.setMode(.expanded)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Compact \(activity.displayName) activity. Tap to expand.")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var leftWing: some View {
        switch activity {
        case .music:
            HStack(spacing: 6) {
                if let artwork = music.artworkImage {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotchColors.accentPrimary)
                }
                Text(music.track?.title ?? "No Music")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
        case .meeting:
            let provider = manager.meetingHeadsUp?.event.meetingProvider ?? "Meeting"
            let isMeet = provider == "Google Meet"
            HStack(spacing: 5) {
                Image(systemName: "video.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isMeet ? NotchColors.statusHealthy : NotchColors.accentPrimary)
                Text(manager.meetingHeadsUp?.event.title ?? "Upcoming Meeting")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
        case .pomodoro:
            let ringColor = productivity.pomodoro.isRunning ? NotchColors.statusAlert : NotchColors.textSecondary
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: productivity.pomodoro.remainingProgress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.4), value: productivity.pomodoro.remainingProgress)
                    if !productivity.pomodoro.isRunning {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 5.5, weight: .bold))
                            .foregroundStyle(NotchColors.textSecondary)
                    }
                }
                .frame(width: 14, height: 14)

                Text(productivity.pomodoro.isRunning ? "Focus" : "Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
        case .ai:
            HStack(spacing: 6) {
                Image(systemName: "command")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(NotchColors.accentPrimary)
                Text("Floqy Agent")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
        case .memory:
            let memColor = system.snapshot.pressureLevel == .critical ? NotchColors.statusAlert : NotchColors.statusWarning
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(memColor)
                Text("RAM High")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        switch activity {
        case .music:
            ZStack(alignment: .trailing) {
                EqualizerBarsView(isPlaying: music.track?.isPlaying == true)
                    .frame(height: 14)
                    .opacity(isHoveringMusicControls ? 0 : 1)
                    .scaleEffect((!reduceMotion && isHoveringMusicControls) ? 0.9 : 1)
                    .allowsHitTesting(false)

                HStack(spacing: 2) {
                    Button {
                        music.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel("Previous track")

                    Button {
                        music.togglePlayPause()
                    } label: {
                        Image(systemName: music.track?.isPlaying == true ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel(music.track?.isPlaying == true ? "Pause" : "Play")

                    Button {
                        music.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(NotchColors.textSecondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                    .accessibilityLabel("Next track")
                }
                .opacity(isHoveringMusicControls ? 1 : 0)
                .scaleEffect((!reduceMotion && !isHoveringMusicControls) ? 0.92 : 1)
                .allowsHitTesting(isHoveringMusicControls)
            }
            .frame(width: 68, height: 24, alignment: .trailing)
            .contentShape(Rectangle())
            .animation(
                reduceMotion ? .easeInOut(duration: 0.12) : .easeOut(duration: 0.16),
                value: isHoveringMusicControls
            )
            .onHover { hovering in
                isHoveringMusicControls = hovering
                manager.setHoveringCompactControls(hovering)
            }
            .onDisappear {
                isHoveringMusicControls = false
                manager.setHoveringCompactControls(false)
            }
        case .meeting:
            let minutes = manager.meetingHeadsUp?.minutesRemaining ?? 5
            Text("in \(minutes)m")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(NotchColors.statusWarning)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(NotchColors.statusWarning.opacity(0.16)))
        case .pomodoro:
            Text(productivity.pomodoro.formattedTime)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(
                    productivity.pomodoro.isRunning ? NotchColors.statusAlert : NotchColors.textSecondary
                )
        case .ai:
            Text("Ready")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchColors.statusHealthy)
        case .memory:
            let memColor = system.snapshot.pressureLevel == .critical ? NotchColors.statusAlert : NotchColors.statusWarning
            Text("\(system.snapshot.usedPercent)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(memColor)
        }
    }
}

/// Actionable notification pill displayed cleanly below the hardware camera cutout.
struct NotchAlertView: View {
    @ObservedObject var manager: NotchManager
    let alert: NotchAlert
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconPopped = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(22, manager.geometry.notchSafeTopHeight - 2))

            HStack(spacing: 10) {
                alertBadge
                alertLabels
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        manager.setMode(.expanded)
                    }
                alertActions
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            if !reduceMotion {
                iconPopped = true
            }
        }
    }

    @ViewBuilder
    private var alertBadge: some View {
        switch alert {
        case .pomodoroComplete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NotchColors.statusHealthy)
                .symbolEffect(.bounce, value: iconPopped)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NotchColors.statusHealthy.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NotchColors.statusHealthy.opacity(0.35), lineWidth: 1)
                        )
                )
        case .meetingStarting(_, _, let provider, _):
            let accent = provider == "Google Meet" ? NotchColors.statusHealthy : NotchColors.accentPrimary
            Image(systemName: "video.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accent.opacity(0.35), lineWidth: 1)
                        )
                )
        }
    }

    @ViewBuilder
    private var alertLabels: some View {
        switch alert {
        case .pomodoroComplete(let durationMinutes):
            VStack(alignment: .leading, spacing: 1) {
                Text("Focus Session Complete")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text("\(durationMinutes)m focus finished")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        case .meetingStarting(_, let title, let provider, _):
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text("\(provider) • Starting now")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var alertActions: some View {
        switch alert {
        case .pomodoroComplete:
            HStack(spacing: 6) {
                Button("Restart") {
                    manager.restartPomodoroFromAlert()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(NotchColors.notchBackground)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(NotchColors.statusHealthy))

                Button("Dismiss") {
                    manager.dismissActiveAlert()
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NotchColors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
        case .meetingStarting(_, _, _, let url):
            HStack(spacing: 6) {
                Button("Join") {
                    manager.joinMeetingFromAlert(url)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(NotchColors.notchBackground)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(NotchColors.accentPrimary))

                Button {
                    manager.dismissActiveAlert()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                .accessibilityLabel("Dismiss meeting notification")
            }
        }
    }
}

/// 4-bar audio equalizer that animates only during active playback and respects Reduce Motion.
struct EqualizerBarsView: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let restHeights: [CGFloat] = [5, 8, 6, 7]
    private let activeHeightsA: [CGFloat] = [12, 7, 14, 9]
    private let activeHeightsB: [CGFloat] = [6, 13, 8, 12]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(NotchColors.accentPrimary)
                    .frame(width: 2.5, height: barHeight(at: index))
                    .animation(barAnimation(at: index), value: pulse)
            }
        }
        .onAppear {
            if isPlaying && !reduceMotion {
                pulse = true
            }
        }
        .onChange(of: isPlaying) { _, playing in
            pulse = playing && !reduceMotion
        }
    }

    private func barHeight(at index: Int) -> CGFloat {
        guard isPlaying else { return restHeights[index] }
        if reduceMotion { return activeHeightsA[index] }
        return pulse ? activeHeightsA[index] : activeHeightsB[index]
    }

    private func barAnimation(at index: Int) -> Animation? {
        guard isPlaying, !reduceMotion else { return .easeOut(duration: 0.15) }
        return .easeInOut(duration: 0.42 + Double(index) * 0.09).repeatForever(autoreverses: true)
    }
}
