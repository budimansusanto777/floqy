import SwiftUI

/// Minimal idle notch surface tucked flush into the hardware bezel.
struct NotchIdleView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                manager.setMode(.expanded)
            }
            .accessibilityElement()
            .accessibilityLabel("Expand Floqy Notch")
            .accessibilityAddTraits(.isButton)
    }
}
