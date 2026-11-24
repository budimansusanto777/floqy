import SwiftUI

/// Compact Live Activity wings displayed on either side of the hardware camera notch.
struct NotchCompactView: View {
    @ObservedObject var manager: NotchManager
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
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchColors.accentPrimary)
                Text("Midnight Flow")
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
                Text("Focus Mode")
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
            HStack(spacing: 2) {
                ForEach([10.0, 14.0, 8.0, 12.0], id: \.self) { height in
                    Capsule()
                        .fill(NotchColors.accentPrimary)
                        .frame(width: 2.5, height: height)
                }
            }
        case .dev:
            Text("68%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NotchColors.accentPrimary)
        case .pomodoro:
            Text("25:00")
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
