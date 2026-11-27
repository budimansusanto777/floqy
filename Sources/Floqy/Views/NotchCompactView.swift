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

    private var dualSlotLayout: CompactDualSlotLayout? {
        guard manager.activeCompactActivities.count >= 2,
              manager.activeCompactActivities.contains(activity) else {
            return nil
        }
        return CompactActivity.dualSlotLayout(
            active: manager.activeCompactActivities,
            overflowOffset: manager.compactOverflowOffset
        )
    }

    var body: some View {
        if let layout = dualSlotLayout, let rightActivity = layout.right {
            dualSlotBody(left: layout.left, right: rightActivity, hidden: layout.hidden)
        } else {
            singleSlotBody
        }
    }

    private var singleSlotBody: some View {
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
            manager.selectTab(activity.targetTab)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Compact \(activity.displayName) activity. Tap to expand.")
        .accessibilityAddTraits(.isButton)
    }

    private func dualSlotBody(
        left: CompactActivity,
        right: CompactActivity,
        hidden: [CompactActivity]
    ) -> some View {
        HStack(spacing: 0) {
            Button {
                manager.selectTab(left.targetTab)
            } label: {
                dualSlotContent(for: left, isCompactRight: false)
                    .padding(.horizontal, 4)
                    .frame(height: 24, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
            .accessibilityLabel("Open \(left.displayName)")
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: manager.geometry.notchCenterGapWidth)

            HStack(spacing: 4) {
                Button {
                    manager.selectTab(right.targetTab)
                } label: {
                    dualSlotContent(for: right, isCompactRight: !hidden.isEmpty)
                        .padding(.horizontal, 4)
                        .frame(height: 24, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                .accessibilityLabel("Open \(right.displayName)")

                if !hidden.isEmpty {
                    let hiddenNames = hidden.map(\.displayName).joined(separator: ", ")
                    Button {
                        manager.cycleCompactOverflow()
                    } label: {
                        Text("+\(hidden.count)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(NotchColors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                            .frame(minWidth: 24, minHeight: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                    .help("Next active: \(hiddenNames) (click to cycle)")
                    .accessibilityLabel("Cycle to next active activity: \(hiddenNames)")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
            .onHover { hovering in
                if !hovering || !hidden.isEmpty {
                    manager.setHoveringCompactControls(hovering)
                }
            }
            .onDisappear {
                manager.setHoveringCompactControls(false)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func dualSlotContent(for item: CompactActivity, isCompactRight: Bool) -> some View {
        switch item {
        case .music:
            HStack(spacing: 5) {
                if let artwork = music.artworkImage {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 15, height: 15)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchColors.accentPrimary)
                }
                Text(music.track?.title ?? "Music")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                EqualizerBarsView(isPlaying: music.track?.isPlaying == true, barCount: 3)
                    .frame(height: 10)
            }
        case .pomodoro:
            let ringColor = productivity.pomodoro.isRunning ? NotchColors.focusAccent : NotchColors.textSecondary
            HStack(spacing: 5) {
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

                Text(productivity.pomodoro.formattedTime)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(ringColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
        case .ai:
            HStack(spacing: 4) {
                Image(systemName: "triangle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchColors.accentPrimary)
                Text(ai.workingAgent?.shortName ?? "AI")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                if !isCompactRight && ai.workingAgent != nil {
                    EqualizerBarsView(isPlaying: true, barCount: 3)
                        .frame(height: 10)
                }
            }
        case .meeting:
            let provider = manager.meetingHeadsUp?.event.meetingProvider ?? "Meeting"
            let isMeet = provider == "Google Meet"
            let minutes = manager.meetingHeadsUp?.minutesRemaining ?? 5
            HStack(spacing: 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isMeet ? NotchColors.statusHealthy : NotchColors.accentPrimary)
                Text("in \(minutes)m")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NotchColors.statusWarning)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(NotchColors.statusWarning.opacity(0.16)))
                    .fixedSize(horizontal: true, vertical: false)
            }
        case .memory:
            let memColor = system.snapshot.pressureLevel == .critical ? NotchColors.statusAlert : NotchColors.statusWarning
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(memColor)
                Text("\(system.snapshot.usedPercent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(memColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
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
    @ObservedObject private var cameraMirror: CameraMirrorService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconPopped = false

    init(manager: NotchManager, alert: NotchAlert) {
        self.manager = manager
        self.alert = alert
        self._cameraMirror = ObservedObject(wrappedValue: manager.cameraMirror)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(22, manager.geometry.notchSafeTopHeight - 2))

            Group {
                if case .chargingConnected(let batteryPercent, let etaText) = alert {
                    chargingTelemetryCard(batteryPercent: batteryPercent, etaText: etaText)
                } else if case .cameraMirror = alert {
                    cameraMirrorCard()
                } else if case .updating(let version) = alert {
                    updateProgressCard(version: version)
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
                case .cameraMirror, .updating:
                    break
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
        .onDisappear {
            if case .cameraMirror = alert {
                manager.cameraMirror.stop()
            }
        }
    }

    private func cameraMirrorCard() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(cameraMirror.isRunning ? NotchColors.statusHealthy : NotchColors.accentPrimary)
                Text("Camera Mirror")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    cameraMirror.isMirrored.toggle()
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(cameraMirror.isMirrored ? NotchColors.accentPrimary : NotchColors.textSecondary)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6, isSelected: cameraMirror.isMirrored))
                .accessibilityLabel("Flip camera mirror")
                .help("Toggle horizontal mirror")

                Button {
                    manager.dismissActiveAlert()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                .accessibilityLabel("Close camera mirror")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.black.opacity(0.45))

                if cameraMirror.errorMessage == nil {
                    CameraPreviewLayerView(
                        session: cameraMirror.session,
                        isMirrored: cameraMirror.isMirrored
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    // Subtle framing guide
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                        .padding(.horizontal, 110)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                } else if let error = cameraMirror.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(NotchColors.textSecondary)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(NotchColors.textSecondary)
                            .multilineTextAlignment(.center)
                        if cameraMirror.authorizationStatus == .denied || cameraMirror.authorizationStatus == .restricted {
                            Button("Open Camera Privacy") {
                                cameraMirror.openCameraPrivacySettings()
                            }
                            .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(NotchColors.accentPrimary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(NotchColors.cardBorder, lineWidth: 1)
            )

            HStack(spacing: 8) {
                Text(cameraMirror.isMirrored ? "Mirrored preview" : "Standard preview")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)

                Spacer(minLength: 4)

                Button("Done") {
                    manager.dismissActiveAlert()
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(NotchColors.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
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

    private func updateProgressCard(version: String) -> some View {
        let info: (Double, String) = {
            if case .installing(let progress, let stage) = manager.updateStatus {
                return (progress, stage)
            }
            return (0.05, "Preparing update…")
        }()
        let clamped = min(1.0, max(0.03, info.0))
        let pct = Int((min(1.0, max(0.0, info.0)) * 100).rounded())

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.accentPrimary)
                Text("Updating to v\(version)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(NotchColors.accentPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NotchColors.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NotchColors.accentPrimary)
                        .frame(width: max(6, geo.size.width * clamped))
                        .animation(.easeOut(duration: 0.2), value: clamped)
                }
            }
            .frame(height: 6)

            HStack {
                Text(info.1)
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
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
        case .chargingConnected, .cameraMirror, .updating:
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
        case .chargingConnected, .cameraMirror, .updating:
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
        case .chargingConnected, .cameraMirror, .updating:
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
