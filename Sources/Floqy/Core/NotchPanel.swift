import AppKit
import SwiftUI

/// Non-activating floating NSPanel anchored above the menu bar at the hardware notch.
final class NotchPanel: NSPanel {
    var allowsKeyFocus: Bool = false
    var onCancel: (() -> Void)?

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = .statusBar + 1
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { allowsKeyFocus }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// Forwards mouse events and hover tracking strictly within the active notch silhouette so clicks
/// and pointer movement outside the visible notch never trigger Floqy or steal focus.
final class NotchPassthroughContainerView<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>
    private var hoverTrackingArea: NSTrackingArea?

    var activeHitRectProvider: (CGSize) -> CGRect
    var onHoverChanged: ((Bool) -> Void)?

    init(rootView: Content, frame: CGRect, activeHitRectProvider: @escaping (CGSize) -> CGRect) {
        self.hostingView = NSHostingView(rootView: rootView)
        self.activeHitRectProvider = activeHitRectProvider
        super.init(frame: frame)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateTrackingRect()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTrackingRect() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let rect = activeHitRectProvider(bounds.size)
        let isInside = window.map {
            rect.contains(convert($0.mouseLocationOutsideOfEventStream, from: nil))
        } ?? false
        var options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        if isInside {
            options.insert(.assumeInside)
        }
        let area = NSTrackingArea(
            rect: rect,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingRect()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard activeHitRectProvider(bounds.size).contains(point) else {
            return nil
        }
        return super.hitTest(point)
    }
}
