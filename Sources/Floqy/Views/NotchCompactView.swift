import SwiftUI

/// Compact Live Activity wings displayed on either side of the hardware camera notch.
struct NotchCompactView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var music: MusicService
    @ObservedObject var productivity: ProductivityService
    @ObservedObject var system: SystemMonitorService
    @ObservedObject var ai: AIService
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
            switch activity {
            case .music:
                manager.selectTab(.home)
            case .pomodoro:
                manager.selectTab(.notes)
            case .ai:
                manager.selectTab(.ai)
            case .memory:
                manager.selectTab(.system)
            case .meeting:
                manager.selectTab(.home)
            }
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
            let ringColor = productivity.pomodoro.isRunning ? NotchColors.focusAccent : NotchColors.textSecondary
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(NotchColors.trackBackground, lineWidth: 2)
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
                Image(systemName: "triangle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchColors.accentPrimary)
                Text(ai.workingAgent?.shortName ?? "Floqy AI")
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
            HStack(spacing: 5) {
                if productivity.pomodoro.isRunning {
                    if manager.idleAppearance == .dog {
                        FloqyPoodleMascotView(mode: .working, width: 26, showSparks: false)
                    } else if manager.idleAppearance == .cat {
                        FloqyCalicoMascotView(mode: .working, width: 26, showSparks: false)
                    }
                }
                Text(productivity.pomodoro.formattedTime)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(
                        productivity.pomodoro.isRunning ? NotchColors.focusAccent : NotchColors.textSecondary
                    )
            }
        case .ai:
            HStack(spacing: 5) {
                if manager.idleAppearance == .dog && ai.workingAgent != nil {
                    FloqyPoodleMascotView(mode: .working, width: 28, showSparks: true)
                    EqualizerBarsView(isPlaying: true, barCount: 3)
                        .frame(height: 11)
                } else if manager.idleAppearance == .cat && ai.workingAgent != nil {
                    FloqyCalicoMascotView(mode: .working, width: 28, showSparks: true)
                    EqualizerBarsView(isPlaying: true, barCount: 3)
                        .frame(height: 11)
                } else {
                    Text(ai.workingAgent != nil ? "Working" : "Ready")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ai.workingAgent != nil ? NotchColors.accentPrimary : NotchColors.statusHealthy)
                    if ai.workingAgent != nil {
                        EqualizerBarsView(isPlaying: true, barCount: 3)
                            .frame(height: 11)
                    }
                }
            }
        case .memory:
            let memColor = system.snapshot.pressureLevel == .critical ? NotchColors.statusAlert : NotchColors.statusWarning
            Text("\(system.snapshot.usedPercent)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(memColor)
        }
    }
}

/// Hardware Card notification pills displayed cleanly below the hardware camera cutout.
struct NotchAlertView: View {
    @ObservedObject var manager: NotchManager
    let alert: NotchAlert
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconPopped = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(22, manager.geometry.notchSafeTopHeight - 2))

            Group {
                if case .chargingConnected(let batteryPercent, let etaText) = alert {
                    chargingTelemetryCard(batteryPercent: batteryPercent, etaText: etaText)
                } else {
                    HStack(spacing: 10) {
                        alertBadge
                        alertLabels
                            .frame(maxWidth: .infinity, alignment: .leading)
                        alertActions
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture {
                switch alert {
                case .aiFinished(let agent):
                    manager.openAgentFromAlert(agent)
                case .headphonesConnected, .chargingConnected:
                    manager.dismissActiveAlert()
                case .pomodoroComplete, .meetingStarting:
                    manager.setMode(.expanded)
                }
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                    iconPopped = true
                }
            }
        }
    }

    private func chargingTelemetryCard(batteryPercent: Int, etaText: String?) -> some View {
        let clampedFraction = CGFloat(min(100, max(0, batteryPercent))) / 100.0
        return VStack(spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.statusHealthy)
                Text("Charging")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                if let etaText {
                    Text("· \(etaText)")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("\(batteryPercent)%")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(NotchColors.statusHealthy)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NotchColors.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NotchColors.statusHealthy)
                        .frame(width: max(6, geo.size.width * clampedFraction))
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Spacer()
                            Rectangle()
                                .fill(NotchColors.notchBackground.opacity(0.6))
                                .frame(width: 1)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 7)
        }
    }

    private func accentColor(for agent: AIAgentKind) -> Color {
        switch agent {
        case .antigravity: return NotchColors.accentPrimary
        case .geminiCLI: return NotchColors.statusHealthy
        case .claudeCode, .claudeDesktop: return NotchColors.focusAccent
        }
    }

    @ViewBuilder
    private var alertBadge: some View {
        switch alert {
        case .pomodoroComplete:
            if manager.idleAppearance == .dog {
                FloqyPoodleMascotView(
                    mode: .done,
                    width: 42,
                    showSparks: true,
                    isCelebrating: iconPopped
                )
            } else if manager.idleAppearance == .cat {
                FloqyCalicoMascotView(
                    mode: .done,
                    width: 44,
                    showSparks: true,
                    isCelebrating: iconPopped
                )
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NotchColors.statusHealthy)
                    .symbolEffect(.bounce, value: iconPopped)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(NotchColors.statusHealthy.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(NotchColors.statusHealthy.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
        case .meetingStarting(_, _, let provider, _):
            let accent = provider == "Google Meet" ? NotchColors.statusHealthy : NotchColors.accentPrimary
            Image(systemName: "video.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(accent.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(accent.opacity(0.35), lineWidth: 1)
                        )
                )
        case .aiFinished(let agent):
            if manager.idleAppearance == .dog {
                FloqyPoodleMascotView(
                    mode: .done,
                    width: 42,
                    showSparks: true,
                    isCelebrating: iconPopped
                )
            } else if manager.idleAppearance == .cat {
                FloqyCalicoMascotView(
                    mode: .done,
                    width: 44,
                    showSparks: true,
                    isCelebrating: iconPopped
                )
            } else {
                let accent = accentColor(for: agent)
                Image(systemName: "triangle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .symbolEffect(.bounce, value: iconPopped)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(accent.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(accent.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
        case .headphonesConnected(_, _, let isAirPods):
            Image(systemName: isAirPods ? "airpodspro" : "headphones")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NotchColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(NotchColors.cardSurface)
                        .overlay(
                            Circle()
                                .stroke(NotchColors.cardBorder, lineWidth: 1)
                        )
                )
        case .chargingConnected:
            EmptyView()
        }
    }

    @ViewBuilder
    private var alertLabels: some View {
        switch alert {
        case .pomodoroComplete(let durationMinutes):
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Session Complete")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text("\(durationMinutes)m focus finished · Session \(manager.productivity.lastCompletedRoundNumber) of 4")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        case .meetingStarting(_, let title, let provider, _):
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text("\(provider) • Starting now")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        case .aiFinished(let agent):
            VStack(alignment: .leading, spacing: 2) {
                Text("\(agent.displayName) finished")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text("Response ready • Click to open")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        case .headphonesConnected(let name, _, _):
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Text("Connected · Audio Output")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
            }
        case .chargingConnected:
            EmptyView()
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
                .foregroundStyle(.white)
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
                .foregroundStyle(NotchColors.accentForeground)
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
        case .aiFinished:
            Text("now")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(NotchColors.textSecondary)
        case .headphonesConnected(_, let batteryPercent, _):
            if let batteryPercent {
                let fraction = CGFloat(min(100, max(0, batteryPercent))) / 100.0
                HStack(spacing: 7) {
                    Text("\(batteryPercent)%")
                        .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(NotchColors.statusHealthy)

                    ZStack {
                        Circle()
                            .stroke(NotchColors.trackBackground, lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: fraction)
                            .stroke(NotchColors.statusHealthy, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 24, height: 24)
                }
            } else {
                Text("Connected")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(NotchColors.statusHealthy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(NotchColors.statusHealthy.opacity(0.14)))
            }
        case .chargingConnected:
            EmptyView()
        }
    }
}

/// Multi-bar kinetic indicator that respects Reduce Motion without sticky CoreAnimation loops.
struct EqualizerBarsView: View {
    let isPlaying: Bool
    var barCount: Int = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let restHeights: [CGFloat] = [5, 8, 6, 7]
    private let activeHeightsA: [CGFloat] = [12, 7, 14, 9]

    var body: some View {
        let count = max(1, min(4, barCount))
        TimelineView(.animation(paused: !isPlaying || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(NotchColors.accentPrimary)
                        .frame(width: 2.5, height: barHeight(at: index, time: t))
                }
            }
        }
    }

    private func barHeight(at index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return restHeights[index] }
        if reduceMotion { return activeHeightsA[index] }
        let speed = 5.4 + Double(index) * 1.15
        let phase = Double(index) * 1.35
        let wave = (sin(time * speed + phase) + 1) * 0.5
        return 5.5 + CGFloat(wave) * 8.5
    }
}
