import SwiftUI

/// Root SwiftUI container hosted inside NotchPanel, rendering the flat hardware-matched shell and state views.
struct NotchRootView: View {
    @ObservedObject var manager: NotchManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpandedContentVisible: Bool = false

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

    private var shellAnimation: Animation {
        let expanding = manager.mode.isExpanded || manager.mode.isAlert
        if reduceMotion {
            return .easeInOut(duration: expanding ? 0.16 : 0.14)
        }
        return expanding
            ? .spring(response: 0.28, dampingFraction: 0.88)
            : .spring(response: 0.22, dampingFraction: 0.96)
    }

    var body: some View {
        let activeTheme = manager.effectiveThemePreset
        let palette = NotchColors.palette(for: activeTheme)
        let animKey = ShellAnimationKey(
            totalWidth: totalWidth,
            shellHeight: shellSize.height,
            earRadius: earRadius,
            bottomRadius: bottomRadius,
            taperedChinInset: taperedChinInset,
            leftLeadingInset: leftLeadingInset,
            isDragTargeted: manager.isDragTargeted
        )

        ZStack(alignment: .top) {
            // 1. Background layer (animates shell geometry cleanly with spring).
            palette.notchBackground
                .animation(.easeOut(duration: manager.mode.isExpanded ? 0.14 : 0.08), value: activeTheme)
                .frame(width: totalWidth, height: shellSize.height, alignment: .top)
                .clipShape(shellShape)
                .animation(shellAnimation, value: animKey)

            // 2. Content layer (synchronous teardown on frame 0 so outgoing mode views never overlap).
            Group {
                switch manager.mode {
                case .idle:
                    NotchIdleView(
                        manager: manager,
                        productivity: manager.productivity,
                        hardware: manager.hardware
                    )
                    .frame(width: idleSize.width, height: idleSize.height)
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
                case .alert(let alert):
                    let alertSize = manager.geometry.shellSize(for: .alert(alert))
                    NotchAlertView(manager: manager, alert: alert)
                        .frame(width: alertSize.width, height: alertSize.height)
                case .expanded:
                    NotchExpandedView(manager: manager)
                        .frame(width: expandedSize.width, height: expandedSize.height)
                        .opacity(reduceMotion || isExpandedContentVisible ? 1 : 0)
                        .scaleEffect(reduceMotion || isExpandedContentVisible ? 1 : 0.97, anchor: .top)
                        .offset(y: reduceMotion || isExpandedContentVisible ? 0 : -6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .mask(alignment: .top) {
                shellShape
                    .frame(width: totalWidth, height: shellSize.height, alignment: .top)
                    .animation(shellAnimation, value: animKey)
            }

            // 3. Border stroke layer.
            shellShape
                .stroke(
                    manager.isDragTargeted ? palette.accentPrimary : palette.shellBorder,
                    lineWidth: manager.isDragTargeted ? 1.5 : (activeTheme == .obsidian ? 0 : 1)
                )
                .frame(width: totalWidth, height: shellSize.height, alignment: .top)
                .allowsHitTesting(false)
                .animation(shellAnimation, value: animKey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.notchThemePreset, activeTheme)
        .environment(\.isDisplayAsleep, manager.isDisplayAsleep)
        .preferredColorScheme(activeTheme.isLight ? .light : .dark)
        .onAppear {
            if manager.mode.isExpanded {
                isExpandedContentVisible = true
            }
        }
        .onChange(of: manager.mode.isExpanded) { _, expanded in
            if expanded {
                if reduceMotion {
                    isExpandedContentVisible = true
                } else {
                    isExpandedContentVisible = false
                    withAnimation(.easeOut(duration: 0.16).delay(0.04)) {
                        isExpandedContentVisible = true
                    }
                }
            } else {
                isExpandedContentVisible = false
            }
        }
    }
}

private struct ShellAnimationKey: Equatable {
    let totalWidth: CGFloat
    let shellHeight: CGFloat
    let earRadius: CGFloat
    let bottomRadius: CGFloat
    let taperedChinInset: CGFloat
    let leftLeadingInset: CGFloat
    let isDragTargeted: Bool
}
