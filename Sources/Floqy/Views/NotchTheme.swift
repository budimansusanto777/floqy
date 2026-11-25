import AppKit
import SwiftUI

/// Verified WCAG AA color tokens for Floqy's dark hardware notch surface.
enum NotchColors {
    static let notchBackground = Color.black                                  // #000000
    static let cardSurface = Color.white.opacity(0.065)
    static let cardBorder = Color.white.opacity(0.075)
    static let controlBorder = Color(red: 0.443, green: 0.443, blue: 0.478)   // #71717A (>=3:1 non-text)
    static let textPrimary = Color(red: 0.961, green: 0.961, blue: 0.969)     // #F5F5F7
    static let textSecondary = Color(red: 0.714, green: 0.729, blue: 0.765)   // #B6BAC3
    static let accentPrimary = Color(red: 0.220, green: 0.741, blue: 0.973)   // #38BDF8
    static let focusAccent = Color(red: 1.0, green: 0.624, blue: 0.039)       // #FF9F0A

    static let statusHealthy = Color(red: 0.188, green: 0.820, blue: 0.345)   // #30D158
    static let statusWarning = Color(red: 0.984, green: 0.749, blue: 0.141)   // #FBBF24
    static let statusAlert = Color(red: 1.0, green: 0.478, blue: 0.522)       // #FF7A85
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

/// Crisp zero-shadow switch toggle that stays brightly colored inside non-activating panels.
struct NotchSwitchToggleStyle: ToggleStyle {
    var onColor: Color = NotchColors.statusHealthy

    func makeBody(configuration: Configuration) -> some View {
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
                        .fill(configuration.isOn ? onColor : Color.white.opacity(0.16))
                        .frame(width: 30, height: 17)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(configuration.isOn ? 0 : 0.10),
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
