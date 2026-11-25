import SwiftUI

/// Root SwiftUI container hosted inside NotchPanel, rendering the flat hardware-matched shell and state views.
struct NotchRootView: View {
    @ObservedObject var manager: NotchManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveHomeSubView: HomeSubView {
        manager.isShowingInlineSettings ? .overview : manager.homeSubView
    }

    private var shellSize: CGSize {
        manager.geometry.shellSize(
            for: manager.mode,
            homeSubView: effectiveHomeSubView,
            activeTab: manager.activeTab,
            idleAppearance: manager.idleAppearance
        )
    }

    private var idleSize: CGSize {
        manager.geometry.shellSize(
            for: .idle,
            idleAppearance: manager.idleAppearance
        )
    }

    private var expandedSize: CGSize {
        manager.geometry.shellSize(
            for: .expanded,
            homeSubView: effectiveHomeSubView,
            activeTab: manager.activeTab,
            idleAppearance: manager.idleAppearance
        )
    }

    private var earRadius: CGFloat {
        if case .idle = manager.mode {
            let needsEars = manager.idleAppearance.isSideWing
                || (manager.idleAppearance.usesBottomChin && manager.idleWidth == .full)
            return needsEars ? NotchGeometry.earWidth : 0
        }
        return NotchGeometry.earWidth
    }

    private var taperedChinInset: CGFloat {
        manager.geometry.taperedChinInset(
            for: manager.mode,
            idleAppearance: manager.idleAppearance,
            idleWidth: manager.idleWidth
        )
    }

    private var leftLeadingInset: CGFloat {
        manager.geometry.leftLeadingInset(
            for: manager.mode,
            idleAppearance: manager.idleAppearance
        )
    }

    private var cameraHeight: CGFloat {
        manager.geometry.notchSafeTopHeight
    }

    private var totalWidth: CGFloat {
        shellSize.width + manager.geometry.earPadding(
            for: manager.mode,
            idleAppearance: manager.idleAppearance,
            idleWidth: manager.idleWidth
        )
    }

    private var bottomRadius: CGFloat {
        manager.geometry.bottomRadius(
            for: manager.mode,
            idleAppearance: manager.idleAppearance,
            idleWidth: manager.idleWidth
        )
    }

    private var shellShape: NotchShellShape {
        NotchShellShape(
            topEarRadius: earRadius,
            bottomCornerRadius: bottomRadius,
            taperedChinInset: taperedChinInset,
            leftLeadingInset: leftLeadingInset,
            cameraHeight: cameraHeight
        )
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
        shellShape
            .fill(NotchColors.notchBackground)
        .overlay(alignment: .top) {
            // Keep each mode view at its natural fixed frame so collapsing never crushes child layouts.
            Group {
                switch manager.mode {
                case .idle:
                    NotchIdleView(
                        manager: manager,
                        productivity: manager.productivity,
                        hardware: manager.hardware
                    )
                    .frame(width: idleSize.width, height: idleSize.height)
                    .transition(.opacity)
                case .compact(let activity):
                    let activityCompactSize = manager.geometry.shellSize(for: .compact(activity))
                    NotchCompactView(
                        manager: manager,
                        music: manager.music,
                        productivity: manager.productivity,
                        system: manager.system,
                        ai: manager.ai,
                        activity: activity
                    )
                    .frame(width: activityCompactSize.width, height: activityCompactSize.height)
                    .compositingGroup()
                    .transition(contentTransition)
                case .alert(let alert):
                    let alertSize = manager.geometry.shellSize(for: .alert(alert))
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
        .clipShape(shellShape)
        .overlay(
            shellShape
                .stroke(
                    manager.isDragTargeted ? NotchColors.accentPrimary : Color.clear,
                    lineWidth: manager.isDragTargeted ? 1.5 : 0
                )
        )
        .frame(width: totalWidth, height: shellSize.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }
}
