import CoreGraphics

@main
enum CoreSelfCheck {
    static func main() {
        checkNotchedScreenDetection()
        checkNonNotchedAndNilScreenFallbacks()
        checkPanelFramesMatchModes()
        checkHitRectsContainedAndOrderedByMode()
        checkNotchShellShapeGeneratesNonEmptyPaths()
        checkSixTabsAreSymmetrical()
        print("CoreSelfCheck: 6/6 checks passed.")
    }

    private static func checkNotchedScreenDetection() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let leftAux = CGRect(x: 0, y: 944, width: 656, height: 38)
        let rightAux = CGRect(x: 856, y: 944, width: 656, height: 38)

        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftAux,
            auxiliaryTopRightArea: rightAux
        )

        precondition(geometry.hasHardwareNotch, "Expected hardware notch to be detected")
        precondition(geometry.hardwareNotchSize.width == 200, "Unexpected notch width")
        precondition(geometry.hardwareNotchSize.height == 38, "Unexpected notch height")
        precondition(geometry.shellSize(for: .idle) == CGSize(width: 200, height: 38), "Idle size mismatch")
        precondition(geometry.notchSafeTopHeight == 38, "Safe top height should match hardware notch height")
        precondition(geometry.notchCenterGapWidth > geometry.hardwareNotchSize.width, "Center gap must clear hardware notch")
        precondition(geometry.shellSize(for: .compact(.music)).width > geometry.notchCenterGapWidth + 160, "Compact wings must clear hardware camera")
    }

    private static func checkNonNotchedAndNilScreenFallbacks() {
        let externalFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let externalGeometry = NotchGeometry(
            screenFrame: externalFrame,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        precondition(!externalGeometry.hasHardwareNotch, "External display should not report hardware notch")
        precondition(externalGeometry.hardwareNotchSize == CGSize(width: 196, height: 32), "External fallback mismatch")
        precondition(externalGeometry.shellSize(for: .idle) == CGSize(width: 196, height: 32), "Idle fallback mismatch")
        precondition(externalGeometry.notchSafeTopHeight == 24, "Fallback safe top height mismatch")

        let nilGeometry = NotchGeometry(screen: nil)
        precondition(!nilGeometry.hasHardwareNotch, "Nil screen should not report hardware notch")
        precondition(nilGeometry.screenFrame == NotchGeometry.fallbackScreenFrame, "Nil screen frame mismatch")
    }

    private static func checkPanelFramesMatchModes() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let leftAux = CGRect(x: 0, y: 944, width: 656, height: 38)
        let rightAux = CGRect(x: 856, y: 944, width: 656, height: 38)
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftAux,
            auxiliaryTopRightArea: rightAux
        )

        let idleFrame = geometry.panelFrame(for: .idle)
        precondition(idleFrame.size == CGSize(width: 200, height: 38), "Idle panel frame must match hardware notch exactly")
        precondition(abs(idleFrame.maxY - screenFrame.maxY) <= 0.5, "Idle panel must anchor to screen top")
        precondition(abs(idleFrame.midX - screenFrame.midX) <= 0.5, "Idle panel must center horizontally")

        let compactFrame = geometry.panelFrame(for: .compact(.music))
        precondition(compactFrame.height <= geometry.hardwareNotchSize.height + 12, "Compact panel height must stay tight")
        precondition(abs(compactFrame.maxY - screenFrame.maxY) <= 0.5, "Compact panel must anchor to screen top")

        let expandedFrame = geometry.panelFrame(for: .expanded)
        precondition(expandedFrame == geometry.panelCanvasFrame(), "Expanded frame must equal panelCanvasFrame")
        precondition(expandedFrame.width == 560 + NotchGeometry.horizontalPadding, "Expanded panel width mismatch")
    }

    private static func checkHitRectsContainedAndOrderedByMode() {
        let geometry = NotchGeometry(screen: nil)
        let canvasBounds = CGRect(origin: .zero, size: geometry.panelCanvasFrame().size)

        let idleOwnFrame = CGRect(origin: .zero, size: geometry.panelFrame(for: .idle).size)
        let idleHitOwn = geometry.hitRectInPanel(for: .idle)
        precondition(idleOwnFrame.contains(idleHitOwn), "Idle hit rect must fit inside idle panel frame")

        let idleHit = geometry.hitRectInPanel(for: .idle, in: canvasBounds.size)
        let compactHit = geometry.hitRectInPanel(for: .compact(.music), in: canvasBounds.size)
        let expandedHit = geometry.hitRectInPanel(for: .expanded, in: canvasBounds.size)

        precondition(canvasBounds.contains(idleHit), "Idle hit rect outside canvas")
        precondition(canvasBounds.contains(compactHit), "Compact hit rect outside canvas")
        precondition(canvasBounds.contains(expandedHit), "Expanded hit rect outside canvas")

        precondition(idleHit.width < compactHit.width, "Idle hit width should be smaller than compact")
        precondition(compactHit.width < expandedHit.width, "Compact hit width should be smaller than expanded")
        precondition(idleHit.maxY == canvasBounds.height, "Idle hit rect should touch top of panel")
        precondition(compactHit.maxY == canvasBounds.height, "Compact hit rect should touch top of panel")
        precondition(expandedHit.maxY == canvasBounds.height, "Expanded hit rect should touch top of panel")
    }

    private static func checkNotchShellShapeGeneratesNonEmptyPaths() {
        let geometry = NotchGeometry(screen: nil)
        for mode in [NotchMode.idle, .compact(.music), .expanded] {
            let size = geometry.shellSize(for: mode)
            let rect = CGRect(
                x: 0,
                y: 0,
                width: size.width + geometry.earPadding(for: mode),
                height: size.height
            )
            let path = NotchShellShape(
                topEarRadius: mode == .idle ? 0 : NotchGeometry.earWidth,
                bottomCornerRadius: geometry.bottomRadius(for: mode)
            ).path(in: rect)
            precondition(!path.isEmpty, "NotchShellShape path should not be empty")
        }
    }

    private static func checkSixTabsAreSymmetrical() {
        precondition(NotchTab.leftTabs.count == 3, "Expected 3 left tabs")
        precondition(NotchTab.rightTabs.count == 3, "Expected 3 right tabs")
        precondition(Set(NotchTab.leftTabs + NotchTab.rightTabs) == Set(NotchTab.allCases), "Tabs must cover all cases")
    }
}
