import SwiftUI

/// Base Settings window for Phase 0 configuration and hardware notch diagnostics.
struct SettingsView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        Form {
            Section("Notch Behavior") {
                Toggle("Auto-expand on hover", isOn: $manager.hoverToExpandEnabled)

                LabeledContent("Global Shortcut") {
                    Text("⌘ ⇧ Space")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
                }
            }

            Section("Display Geometry") {
                LabeledContent("Hardware Notch") {
                    Text(manager.geometry.hasHardwareNotch ? "Detected" : "Fallback Mode")
                        .foregroundStyle(manager.geometry.hasHardwareNotch ? .green : .secondary)
                }
                LabeledContent("Notch Frame") {
                    let size = manager.geometry.hardwareNotchSize
                    Text("\(Int(size.width)) × \(Int(size.height)) pt")
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("About Floqy") {
                LabeledContent("Version", value: "0.1.0 (Phase 0)")
                LabeledContent("License", value: "GNU GPLv3")
                LabeledContent("Copyright", value: "© 2026 budimansusanto777")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 290)
    }
}
