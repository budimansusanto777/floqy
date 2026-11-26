import AppKit

/// Computes hardware notch dimensions, mode-sized panel frames, and hit-test rects across displays.
struct NotchGeometry: Equatable {
    static let earWidth: CGFloat = 12
    static let horizontalPadding: CGFloat = 24 // 12pt concave ear on each side
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

    static let idleChinWidth: CGFloat = 92
    static let sideWingWidth: CGFloat = 44
    static let sideWingSlotWidth: CGFloat = sideWingWidth + earWidth

    func earPadding(
        for mode: NotchMode,
        idleAppearance: IdleAppearance = .off,
        idleWidth: IdleNotchWidth = .compact
    ) -> CGFloat {
        if case .idle = mode {
            return (idleAppearance.usesBottomChin && idleWidth == .full) ? Self.horizontalPadding : 0
        }
        return Self.horizontalPadding
    }

    func bottomPadding(for mode: NotchMode, idleAppearance: IdleAppearance = .off) -> CGFloat {
        if case .idle = mode {
            return idleAppearance.usesBottomChin ? 2 : 0
        }
        return 2
    }

    /// Returns the content shell size (excluding the outer concave ears) for a given notch mode and active sub-view.
    func shellSize(
        for mode: NotchMode,
        homeSubView: HomeSubView = .overview,
        activeTab: NotchTab = .home,
        idleAppearance: IdleAppearance = .off
    ) -> CGSize {
        switch mode {
        case .idle:
            let baseWidth = hasHardwareNotch ? hardwareNotchSize.width : 196
            if idleAppearance.isSideWing {
                return CGSize(
                    width: baseWidth + Self.sideWingSlotWidth * 2,
                    height: hasHardwareNotch ? hardwareNotchSize.height : 34
                )
            }
            if idleAppearance.usesBottomChin {
                return CGSize(width: baseWidth, height: notchSafeTopHeight + 20)
            }
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
        case .alert(let alert):
            switch alert {
            case .headphonesConnected, .chargingConnected:
                return CGSize(width: 376, height: max(86, notchSafeTopHeight + 52))
            case .aiFinished:
                return CGSize(width: 392, height: max(84, notchSafeTopHeight + 50))
            case .pomodoroComplete, .meetingStarting:
                return CGSize(width: 424, height: max(86, notchSafeTopHeight + 52))
            }
        case .expanded:
            let rawWidth: CGFloat = hasHardwareNotch
                ? max(596, hardwareNotchSize.width + 396)
                : 596
            let expandedWidth = ceil(rawWidth / 2) * 2
            if activeTab == .home && homeSubView == .calendar {
                return CGSize(width: expandedWidth, height: max(268, notchSafeTopHeight + 234))
            }
            return CGSize(width: expandedWidth, height: max(224, notchSafeTopHeight + 190))
        }
    }

    func bottomRadius(
        for mode: NotchMode,
        idleAppearance: IdleAppearance = .off,
        idleWidth: IdleNotchWidth = .compact
    ) -> CGFloat {
        switch mode {
        case .idle:
            if idleAppearance.isSideWing {
                return 12
            }
            return (idleAppearance.usesBottomChin && idleWidth == .compact) ? 12 : 16
        case .compact: return 14
        case .alert: return 26
        case .expanded: return 26
        }
    }

    /// Horizontal inset from each side of the camera cutout to form the tapered idle mini-chin.
    func taperedChinInset(
        for mode: NotchMode,
        idleAppearance: IdleAppearance = .off,
        idleWidth: IdleNotchWidth = .compact
    ) -> CGFloat {
        guard case .idle = mode, idleAppearance.usesBottomChin, idleWidth == .compact else { return 0 }
        let baseWidth = hasHardwareNotch ? hardwareNotchSize.width : 196
        return max(0, (baseWidth - Self.idleChinWidth) / 2)
    }

    /// Leading transparent inset inside the centered panel (0 so Cat and Dog share both wings).
    func leftLeadingInset(
        for mode: NotchMode,
        idleAppearance: IdleAppearance = .off
    ) -> CGFloat {
        return 0
    }

    /// Anchors any given panel size horizontally centered at the top bezel of the target screen.
    func centeredFrame(size: CGSize) -> CGRect {
        let originX = round(screenFrame.midX - (size.width / 2))
        let originY = round(screenFrame.maxY - size.height)
        return CGRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    /// Returns the NSPanel frame sized for the given mode/sub-view and anchored top-center on the target screen.
    func panelFrame(
        for mode: NotchMode,
        homeSubView: HomeSubView = .overview,
        activeTab: NotchTab = .home,
        idleAppearance: IdleAppearance = .off,
        idleWidth: IdleNotchWidth = .compact
    ) -> CGRect {
        let shell = shellSize(
            for: mode,
            homeSubView: homeSubView,
            activeTab: activeTab,
            idleAppearance: idleAppearance
        )
        let totalWidth = shell.width + earPadding(
            for: mode,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        )
        let totalHeight = shell.height + bottomPadding(for: mode, idleAppearance: idleAppearance)
        return centeredFrame(size: CGSize(width: totalWidth, height: totalHeight))
    }

    /// Maximum expanded NSPanel canvas frame anchored at the top-center of the target screen.
    func panelCanvasFrame(
        idleAppearance: IdleAppearance = .off,
        idleWidth: IdleNotchWidth = .compact
    ) -> CGRect {
        panelFrame(
            for: .expanded,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        )
    }

    /// Active notch hit-test rect (shell + active ears) in AppKit panel-local bottom-left coordinates.
    func hitRectInPanel(
        for mode: NotchMode,
        homeSubView: HomeSubView = .overview,
        activeTab: NotchTab = .home,
        idleAppearance: IdleAppearance = .off,
        idleWidth: IdleNotchWidth = .compact,
        in containerSize: CGSize? = nil
    ) -> CGRect {
        let size = containerSize ?? panelFrame(
            for: mode,
            homeSubView: homeSubView,
            activeTab: activeTab,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        ).size
        let shell = shellSize(
            for: mode,
            homeSubView: homeSubView,
            activeTab: activeTab,
            idleAppearance: idleAppearance
        )
        let totalWidth = shell.width + earPadding(
            for: mode,
            idleAppearance: idleAppearance,
            idleWidth: idleWidth
        )
        let leftInset = leftLeadingInset(for: mode, idleAppearance: idleAppearance)
        let originX = (size.width - totalWidth) / 2 + leftInset
        let originY = size.height - shell.height
        let activeWidth = max(0, totalWidth - leftInset)
        return CGRect(x: originX, y: originY, width: activeWidth, height: shell.height)
    }

    /// Pure screen-index resolver supporting Built-in Notch, Primary, and Follow-Cursor strategies.
    static func resolveScreenIndex(
        frames: [CGRect],
        notchedIndices: Set<Int>,
        preference: DisplayPreference,
        cursor: CGPoint
    ) -> Int? {
        guard !frames.isEmpty else { return nil }
        let primaryIndex = frames.firstIndex(where: { $0.origin == .zero }) ?? 0

        switch preference {
        case .builtInNotch:
            return frames.indices.first(where: { notchedIndices.contains($0) }) ?? primaryIndex
        case .primary:
            return primaryIndex
        case .followCursor:
            return frames.indices.first(where: { frames[$0].contains(cursor) }) ?? primaryIndex
        }
    }

    /// Selects the host screen matching the user's multi-monitor DisplayPreference.
    static func preferredScreen(
        for preference: DisplayPreference = .builtInNotch,
        mouseLocation: NSPoint = NSEvent.mouseLocation
    ) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return NSScreen.main }
        let frames = screens.map(\.frame)
        let notched = Set(screens.indices.filter {
            screens[$0].auxiliaryTopLeftArea != nil && screens[$0].auxiliaryTopRightArea != nil
        })
        if let index = resolveScreenIndex(
            frames: frames,
            notchedIndices: notched,
            preference: preference,
            cursor: mouseLocation
        ) {
            return screens[index]
        }
        return NSScreen.main ?? screens.first
    }
}
