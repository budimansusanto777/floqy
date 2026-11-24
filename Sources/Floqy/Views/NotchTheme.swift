import AppKit
import SwiftUI

/// Verified WCAG AA color tokens for Floqy's dark hardware notch surface.
enum NotchColors {
    static let notchBackground = Color(red: 0.027, green: 0.027, blue: 0.035) // #070709
    static let cardSurface = Color(red: 0.078, green: 0.078, blue: 0.094)     // #141418
    static let cardBorder = Color(red: 0.173, green: 0.173, blue: 0.204)      // #2C2C34
    static let controlBorder = Color(red: 0.443, green: 0.443, blue: 0.478)   // #71717A (>=3:1 non-text)
    static let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.965)     // #F4F4F6
    static let textSecondary = Color(red: 0.631, green: 0.631, blue: 0.667)   // #A1A1AA
    static let accentPrimary = Color(red: 0.220, green: 0.741, blue: 0.973)   // #38BDF8

    static let statusHealthy = Color(red: 0.204, green: 0.827, blue: 0.600)   // #34D399
    static let statusWarning = Color(red: 0.984, green: 0.749, blue: 0.141)   // #FBBF24
    static let statusAlert = Color(red: 0.984, green: 0.443, blue: 0.522)     // #FB7185
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

    @State private var isHovering = false

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
            return Color.white.opacity(0.16)
        }
        return isHovering ? Color.white.opacity(0.12) : Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return NotchColors.controlBorder
        }
        return isHovering ? NotchColors.controlBorder.opacity(0.75) : Color.clear
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
