import AppKit

/// Computes hardware notch dimensions, mode-sized panel frames, and hit-test rects across displays.
struct NotchGeometry: Equatable {
    static let earWidth: CGFloat = 12
    static let horizontalPadding: CGFloat = 24 // 12pt concave ear on each side
    static let bottomShadowPadding: CGFloat = 24
    static let fallbackScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    let hasHardwareNotch: Bool
    let hardwareNotchSize: CGSize
    let screenFrame: CGRect

    init(
        screenFrame: CGRect,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?
    ) {
        self.screenFrame = screenFrame

        if let leftArea = auxiliaryTopLeftArea,
           let rightArea = auxiliaryTopRightArea {
            let notchWidth = max(140, screenFrame.width - leftArea.width - rightArea.width)
            let notchHeight = max(28, leftArea.height)
            self.hasHardwareNotch = true
            self.hardwareNotchSize = CGSize(width: notchWidth, height: notchHeight)
        } else {
            self.hasHardwareNotch = false
            self.hardwareNotchSize = CGSize(width: 196, height: 32)
        }
    }

    init(screen: NSScreen?) {
        if let screen {
            self.init(
                screenFrame: screen.frame,
                auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: screen.auxiliaryTopRightArea
            )
        } else {
            self.init(
                screenFrame: Self.fallbackScreenFrame,
                auxiliaryTopLeftArea: nil,
                auxiliaryTopRightArea: nil
            )
        }
    }

    /// Vertical clearance reserved for the hardware camera notch (or top bar on external screens).
    var notchSafeTopHeight: CGFloat {
        hasHardwareNotch ? hardwareNotchSize.height : 24
    }

    /// Horizontal gap at the top-center so wings and top controls never sit behind the hardware camera.
    var notchCenterGapWidth: CGFloat {
        hasHardwareNotch ? hardwareNotchSize.width + 12 : 48
    }

    func earPadding(for mode: NotchMode) -> CGFloat {
        mode == .idle ? 0 : Self.horizontalPadding
    }

    func bottomPadding(for mode: NotchMode) -> CGFloat {
        mode == .idle ? 0 : 2
    }

    /// Returns the content shell size (excluding the outer concave ears) for a given notch mode and active sub-view.
    func shellSize(
        for mode: NotchMode,
        homeSubView: HomeSubView = .overview,
        activeTab: NotchTab = .home
    ) -> CGSize {
        switch mode {
        case .idle:
            return hasHardwareNotch
                ? hardwareNotchSize
                : CGSize(width: 196, height: 32)
        case .compact:
            let rawWidth: CGFloat = hasHardwareNotch
                ? max(380, hardwareNotchSize.width + 188)
                : 360
            let compactWidth = ceil(rawWidth / 2) * 2
            return CGSize(
                width: compactWidth,
                height: hasHardwareNotch ? hardwareNotchSize.height : 34
            )
        case .alert:
            return CGSize(width: 416, height: max(82, notchSafeTopHeight + 50))
        case .expanded:
            if activeTab == .home && homeSubView == .calendar {
                return CGSize(width: 560, height: max(268, notchSafeTopHeight + 234))
            }
            return CGSize(width: 560, height: max(228, notchSafeTopHeight + 194))
        }
    }

    var bottomCornerRadius: CGFloat { 26 }

    func bottomRadius(for mode: NotchMode) -> CGFloat {
        switch mode {
        case .idle: return 16
        case .compact: return 14
        case .alert: return 22
        case .expanded: return 24
        }
    }

    /// Returns the NSPanel frame sized for the given mode/sub-view and anchored top-center on the target screen.
    func panelFrame(
        for mode: NotchMode,
        homeSubView: HomeSubView = .overview,
        activeTab: NotchTab = .home
    ) -> CGRect {
        let shell = shellSize(for: mode, homeSubView: homeSubView, activeTab: activeTab)
        let totalWidth = shell.width + earPadding(for: mode)
        let totalHeight = shell.height + bottomPadding(for: mode)
        let originX = round(screenFrame.midX - (totalWidth / 2))
        let originY = round(screenFrame.maxY - totalHeight)
        return CGRect(x: originX, y: originY, width: totalWidth, height: totalHeight)
    }

    /// Maximum expanded NSPanel canvas frame anchored at the top-center of the target screen.
    func panelCanvasFrame() -> CGRect {
        panelFrame(for: .expanded)
    }

    /// Active notch hit-test rect (shell + active ears) in AppKit panel-local bottom-left coordinates.
    func hitRectInPanel(
        for mode: NotchMode,
        homeSubView: HomeSubView = .overview,
        activeTab: NotchTab = .home,
        in containerSize: CGSize? = nil
    ) -> CGRect {
        let size = containerSize ?? panelFrame(for: mode, homeSubView: homeSubView, activeTab: activeTab).size
        let shell = shellSize(for: mode, homeSubView: homeSubView, activeTab: activeTab)
        let totalWidth = shell.width + earPadding(for: mode)
        let originX = (size.width - totalWidth) / 2
        let originY = size.height - shell.height
        return CGRect(x: originX, y: originY, width: totalWidth, height: shell.height)
    }

    /// Preferred display: built-in notched display if present, otherwise the primary screen.
    static func preferredScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: {
            $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}
