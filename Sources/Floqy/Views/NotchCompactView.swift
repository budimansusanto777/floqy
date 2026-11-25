import SwiftUI

/// Compact Live Activity wings displayed on either side of the hardware camera notch.
struct NotchCompactView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var music: MusicService
    @ObservedObject var productivity: ProductivityService
    let activity: CompactActivity

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
        case .dev:
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchColors.accentPrimary)
                Text("swift build")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
        case .pomodoro:
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchColors.statusAlert)
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
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(NotchColors.statusWarning)
                Text("RAM Pressure")
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
            EqualizerBarsView(isPlaying: music.track?.isPlaying == true)
                .frame(height: 14)
        case .dev:
            Text("68%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NotchColors.accentPrimary)
        case .pomodoro:
            Text(productivity.pomodoro.formattedTime)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NotchColors.statusAlert)
        case .ai:
            Text("Ready")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchColors.statusHealthy)
        case .memory:
            Text("77%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NotchColors.statusWarning)
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
