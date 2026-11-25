import SwiftUI

/// Root SwiftUI container hosted inside NotchPanel, rendering the hardware-matched shell and state views.
struct NotchRootView: View {
    @ObservedObject var manager: NotchManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseActive = false

    private var shellSize: CGSize {
        manager.geometry.shellSize(
            for: manager.mode,
            homeSubView: manager.homeSubView,
            activeTab: manager.activeTab
        )
    }

    private var idleSize: CGSize {
        manager.geometry.shellSize(for: .idle)
    }

    private var alertSize: CGSize {
        manager.geometry.shellSize(for: .alert(.pomodoroComplete(durationMinutes: 25)))
    }

    private var expandedSize: CGSize {
        manager.geometry.shellSize(
            for: .expanded,
            homeSubView: manager.homeSubView,
            activeTab: manager.activeTab
        )
    }

    private var earRadius: CGFloat {
        manager.mode == .idle ? 0 : NotchGeometry.earWidth
    }

    private var totalWidth: CGFloat {
        shellSize.width + manager.geometry.earPadding(for: manager.mode)
    }

    private var bottomRadius: CGFloat {
        manager.geometry.bottomRadius(for: manager.mode)
    }

    private var isPomodoroCompleteAlert: Bool {
        if case .alert(.pomodoroComplete) = manager.mode { return true }
        return false
    }

    private var borderStrokeColor: Color {
        if manager.isDragTargeted {
            return NotchColors.accentPrimary
        }
        if isPomodoroCompleteAlert {
            return NotchColors.statusHealthy.opacity(pulseActive ? 0.95 : 0.45)
        }
        if case .alert(.meetingStarting(_, _, let provider, _)) = manager.mode {
            let accent = provider == "Google Meet" ? NotchColors.statusHealthy : NotchColors.accentPrimary
            return accent.opacity(0.45)
        }
        return Color.white.opacity(manager.mode == .idle ? 0.0 : 0.14)
    }

    private var contentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.16).delay(0.05)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }

    var body: some View {
        NotchShellShape(
            topEarRadius: earRadius,
            bottomCornerRadius: bottomRadius
        )
        .fill(NotchColors.notchBackground)
        .overlay(
            Group {
                if isPomodoroCompleteAlert {
                    NotchShellShape(
                        topEarRadius: earRadius,
                        bottomCornerRadius: bottomRadius
                    )
                    .stroke(
                        NotchColors.statusHealthy.opacity(pulseActive ? 0.55 : 0.2),
                        lineWidth: 6
                    )
                    .blur(radius: 4)
                }
            }
            .clipShape(
                NotchShellShape(
                    topEarRadius: earRadius,
                    bottomCornerRadius: bottomRadius
                )
            )
        )
        .overlay(alignment: .top) {
            // Keep each mode view at its natural fixed frame so collapsing never crushes child layouts.
            Group {
                switch manager.mode {
                case .idle:
                    NotchIdleView(manager: manager)
                        .frame(width: idleSize.width, height: idleSize.height)
                        .transition(.opacity)
                case .compact(let activity):
                    let activityCompactSize = manager.geometry.shellSize(for: .compact(activity))
                    NotchCompactView(
                        manager: manager,
                        music: manager.music,
                        productivity: manager.productivity,
                        activity: activity
                    )
                    .frame(width: activityCompactSize.width, height: activityCompactSize.height)
                    .compositingGroup()
                    .transition(contentTransition)
                case .alert(let alert):
                    NotchAlertView(manager: manager, alert: alert)
                        .frame(width: alertSize.width, height: alertSize.height)
                        .compositingGroup()
                        .transition(contentTransition)
                case .expanded:
                    NotchExpandedView(manager: manager)
                        .frame(width: expandedSize.width, height: expandedSize.height)
                        .compositingGroup()
                        .transition(contentTransition)
                }
            }
        }
        .clipShape(
            NotchShellShape(
                topEarRadius: earRadius,
                bottomCornerRadius: bottomRadius
            )
        )
        .overlay(
            NotchShellShape(
                topEarRadius: earRadius,
                bottomCornerRadius: bottomRadius
            )
            .stroke(
                borderStrokeColor,
                lineWidth: (manager.isDragTargeted || isPomodoroCompleteAlert) ? 1.5 : 1
            )
        )
        .frame(width: totalWidth, height: shellSize.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isPomodoroCompleteAlert) { _, active in
            triggerGlowPulseIfNeeded(active)
        }
        .onAppear {
            triggerGlowPulseIfNeeded(isPomodoroCompleteAlert)
        }
        .preferredColorScheme(.dark)
    }

    private func triggerGlowPulseIfNeeded(_ active: Bool) {
        guard active, !reduceMotion else {
            pulseActive = false
            return
        }
        pulseActive = false
        withAnimation(.easeInOut(duration: 0.55).repeatCount(5, autoreverses: true)) {
            pulseActive = true
        }
    }
}
