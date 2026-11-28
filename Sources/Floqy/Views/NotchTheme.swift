import AppKit
import ObjectiveC
import SwiftUI

private struct NotchThemePresetKey: EnvironmentKey {
    static let defaultValue: NotchThemePreset = .obsidian
}

extension EnvironmentValues {
    var notchThemePreset: NotchThemePreset {
        get { self[NotchThemePresetKey.self] }
        set { self[NotchThemePresetKey.self] = newValue }
    }
}

/// Complete WCAG-conscious palette for Floqy's notch shell, cards, and controls.
struct NotchPalette {
    let notchBackground: Color
    let shellBorder: Color
    let cardSurface: Color
    let cardBorder: Color
    let controlSurface: Color
    let controlSubtle: Color
    let controlSelected: Color
    let controlBorder: Color
    let trackBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let accentPrimary: Color
    let accentForeground: Color
    let focusAccent: Color
    let statusHealthy: Color
    let statusWarning: Color
    let statusAlert: Color
    let petAccentCutout: Color
    let isLight: Bool
}

/// Dynamic semantic color tokens synchronized with the user's selected notch theme.
enum NotchColors {
    static var activePreset: NotchThemePreset = .obsidian

    static var current: NotchPalette {
        palette(for: activePreset)
    }

    static var notchBackground: Color { current.notchBackground }
    static var shellBorder: Color { current.shellBorder }
    static var cardSurface: Color { current.cardSurface }
    static var cardBorder: Color { current.cardBorder }
    static var controlSurface: Color { current.controlSurface }
    static var controlSubtle: Color { current.controlSubtle }
    static var controlSelected: Color { current.controlSelected }
    static var controlBorder: Color { current.controlBorder }
    static var trackBackground: Color { current.trackBackground }
    static var textPrimary: Color { current.textPrimary }
    static var textSecondary: Color { current.textSecondary }
    static var accentPrimary: Color { current.accentPrimary }
    static var accentForeground: Color { current.accentForeground }
    static var focusAccent: Color { current.focusAccent }
    static var statusHealthy: Color { current.statusHealthy }
    static var statusWarning: Color { current.statusWarning }
    static var statusAlert: Color { current.statusAlert }
    static var petAccentCutout: Color { current.petAccentCutout }

    static func palette(for preset: NotchThemePreset) -> NotchPalette {
        switch preset {
        case .obsidian:
            return NotchPalette(
                notchBackground: .black,
                shellBorder: .clear,
                cardSurface: Color.white.opacity(0.065),
                cardBorder: Color.white.opacity(0.075),
                controlSurface: Color.white.opacity(0.06),
                controlSubtle: Color.white.opacity(0.04),
                controlSelected: Color.white.opacity(0.15),
                controlBorder: Color(red: 0.443, green: 0.443, blue: 0.478),
                trackBackground: Color.white.opacity(0.16),
                textPrimary: Color(red: 0.961, green: 0.961, blue: 0.969),
                textSecondary: Color(red: 0.714, green: 0.729, blue: 0.765),
                accentPrimary: Color(red: 0.220, green: 0.741, blue: 0.973),
                accentForeground: .black,
                focusAccent: Color(red: 1.0, green: 0.624, blue: 0.039),
                statusHealthy: Color(red: 0.188, green: 0.820, blue: 0.345),
                statusWarning: Color(red: 0.984, green: 0.749, blue: 0.141),
                statusAlert: Color(red: 1.0, green: 0.478, blue: 0.522),
                petAccentCutout: .black,
                isLight: false
            )

        case .midnight:
            return NotchPalette(
                notchBackground: Color(red: 11 / 255, green: 16 / 255, blue: 26 / 255),
                shellBorder: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.20),
                cardSurface: Color(red: 19 / 255, green: 27 / 255, blue: 43 / 255),
                cardBorder: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.18),
                controlSurface: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.11),
                controlSubtle: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.07),
                controlSelected: Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255).opacity(0.22),
                controlBorder: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.45),
                trackBackground: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.22),
                textPrimary: Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255),
                textSecondary: Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255),
                accentPrimary: Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255),
                accentForeground: Color(red: 4 / 255, green: 21 / 255, blue: 34 / 255),
                focusAccent: Color(red: 1.0, green: 0.624, blue: 0.039),
                statusHealthy: Color(red: 0.188, green: 0.820, blue: 0.345),
                statusWarning: Color(red: 0.984, green: 0.749, blue: 0.141),
                statusAlert: Color(red: 1.0, green: 0.478, blue: 0.522),
                petAccentCutout: .black,
                isLight: false
            )

        case .pureWhite:
            return NotchPalette(
                notchBackground: Color(red: 247 / 255, green: 247 / 255, blue: 248 / 255),
                shellBorder: Color.black.opacity(0.14),
                cardSurface: .white,
                cardBorder: Color.black.opacity(0.10),
                controlSurface: Color.black.opacity(0.055),
                controlSubtle: Color.black.opacity(0.035),
                controlSelected: Color.black.opacity(0.11),
                controlBorder: Color.black.opacity(0.28),
                trackBackground: Color.black.opacity(0.16),
                textPrimary: Color(red: 22 / 255, green: 22 / 255, blue: 24 / 255),
                textSecondary: Color(red: 94 / 255, green: 96 / 255, blue: 104 / 255),
                accentPrimary: Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255),
                accentForeground: .white,
                focusAccent: Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255),
                statusHealthy: Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255),
                statusWarning: Color(red: 202 / 255, green: 138 / 255, blue: 4 / 255),
                statusAlert: Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255),
                petAccentCutout: .white,
                isLight: true
            )

        case .sakuraBlush:
            return NotchPalette(
                notchBackground: Color(red: 253 / 255, green: 242 / 255, blue: 246 / 255),
                shellBorder: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.20),
                cardSurface: .white,
                cardBorder: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.15),
                controlSurface: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.07),
                controlSubtle: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.045),
                controlSelected: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.14),
                controlBorder: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.32),
                trackBackground: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255).opacity(0.18),
                textPrimary: Color(red: 45 / 255, green: 22 / 255, blue: 34 / 255),
                textSecondary: Color(red: 125 / 255, green: 81 / 255, blue: 102 / 255),
                accentPrimary: Color(red: 219 / 255, green: 39 / 255, blue: 119 / 255),
                accentForeground: .white,
                focusAccent: Color(red: 225 / 255, green: 29 / 255, blue: 116 / 255),
                statusHealthy: Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255),
                statusWarning: Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255),
                statusAlert: Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255),
                petAccentCutout: .white,
                isLight: true
            )

        case .roseVelvet:
            return NotchPalette(
                notchBackground: Color(red: 23 / 255, green: 14 / 255, blue: 21 / 255),
                shellBorder: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.22),
                cardSurface: Color(red: 35 / 255, green: 22 / 255, blue: 32 / 255),
                cardBorder: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.18),
                controlSurface: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.11),
                controlSubtle: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.07),
                controlSelected: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.22),
                controlBorder: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.45),
                trackBackground: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255).opacity(0.22),
                textPrimary: Color(red: 253 / 255, green: 242 / 255, blue: 248 / 255),
                textSecondary: Color(red: 196 / 255, green: 159 / 255, blue: 180 / 255),
                accentPrimary: Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255),
                accentForeground: Color(red: 41 / 255, green: 8 / 255, blue: 24 / 255),
                focusAccent: Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255),
                statusHealthy: Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255),
                statusWarning: Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255),
                statusAlert: Color(red: 251 / 255, green: 113 / 255, blue: 133 / 255),
                petAccentCutout: .black,
                isLight: false
            )
        }
    }
}

/// Interactive button style with distinct hover, active, focus, and pointer-cursor feedback.
struct NotchInteractiveButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        NotchInteractiveButtonBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            isSelected: isSelected
        )
    }
}

private struct NotchInteractiveButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let cornerRadius: CGFloat
    let isSelected: Bool

    @Environment(\.notchThemePreset) private var themePreset
    @State private var isHovering = false

    private var palette: NotchPalette {
        NotchColors.palette(for: themePreset)
    }

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .modifier(PointerCursorModifier(isHovering: $isHovering))
    }

    private var backgroundColor: Color {
        if isSelected {
            return palette.controlSelected
        }
        return isHovering ? palette.controlSurface : Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return palette.controlBorder
        }
        return isHovering ? palette.controlBorder.opacity(0.75) : Color.clear
    }
}

/// Balances NSCursor.pointingHand push/pop across hover and view disappearance.
struct PointerCursorModifier: ViewModifier {
    @Binding var isHovering: Bool

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                updateCursor(hovering)
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
    }

    private func updateCursor(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }
}

/// Crisp zero-shadow switch toggle that stays brightly colored inside non-activating panels.
struct NotchSwitchToggleStyle: ToggleStyle {
    var onColor: Color?

    @Environment(\.notchThemePreset) private var themePreset

    func makeBody(configuration: Configuration) -> some View {
        let palette = NotchColors.palette(for: themePreset)
        let activeColor = onColor ?? palette.statusHealthy

        HStack(spacing: 8) {
            configuration.label
            Spacer(minLength: 8)
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    configuration.isOn.toggle()
                }
            } label: {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(configuration.isOn ? activeColor : palette.trackBackground)
                        .frame(width: 30, height: 17)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    configuration.isOn ? Color.clear : palette.cardBorder,
                                    lineWidth: 0.75
                                )
                        )

                    Circle()
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .offset(x: configuration.isOn ? 6.5 : -6.5)
                }
                .animation(.easeOut(duration: 0.16), value: configuration.isOn)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.isOn ? "On" : "Off")
        }
    }
}

/// Presents a native AppKit context menu that remains visible and reliable inside non-activating panels.
enum NotchPopupMenu {
    @MainActor
    static func show<T: Equatable>(
        items: [(title: String, value: T)],
        selected: T,
        onSelect: @escaping @MainActor (T) -> Void
    ) {
        let menu = NSMenu()
        let handler = PopupMenuActionHandler { index in
            guard items.indices.contains(index) else { return }
            onSelect(items[index].value)
        }
        objc_setAssociatedObject(
            menu,
            &PopupMenuActionHandler.associationKey,
            handler,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        for (index, item) in items.enumerated() {
            let menuItem = NSMenuItem(
                title: item.title,
                action: #selector(PopupMenuActionHandler.handleSelection(_:)),
                keyEquivalent: ""
            )
            menuItem.target = handler
            menuItem.tag = index
            menuItem.state = (item.value == selected) ? .on : .off
            menu.addItem(menuItem)
        }

        let selectedItem = menu.items.first(where: { $0.state == .on })
        menu.popUp(positioning: selectedItem, at: NSEvent.mouseLocation, in: nil)
    }
}

private final class PopupMenuActionHandler: NSObject {
    nonisolated(unsafe) static var associationKey: UInt8 = 0
    private let onIndex: @MainActor (Int) -> Void

    init(onIndex: @escaping @MainActor (Int) -> Void) {
        self.onIndex = onIndex
    }

    @objc func handleSelection(_ sender: NSMenuItem) {
        let index = sender.tag
        Task { @MainActor [onIndex] in
            onIndex(index)
        }
    }
}
