import SwiftUI
import UniformTypeIdentifiers

/// Root SwiftUI container hosted inside NotchPanel, rendering the hardware-matched shell and state views.
struct NotchRootView: View {
    @ObservedObject var manager: NotchManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragTargeted = false

    private var shellSize: CGSize {
        manager.geometry.shellSize(
            for: manager.mode,
            homeSubView: manager.homeSubView,
            activeTab: manager.activeTab
        )
    }

    private var earRadius: CGFloat {
        manager.mode == .idle ? 0 : NotchGeometry.earWidth
    }

    private var totalWidth: CGFloat {
        shellSize.width + manager.geometry.earPadding(for: manager.mode)
    }

    private var bottomRadius: CGFloat {
        manager.geometry.bottomRadius(for: manager.mode)
    }

    private var transitionAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.42, dampingFraction: 0.82)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShellShape(
                topEarRadius: earRadius,
                bottomCornerRadius: bottomRadius
            )
            .fill(NotchColors.notchBackground)
            .overlay(
                NotchShellShape(
                    topEarRadius: earRadius,
                    bottomCornerRadius: bottomRadius
                )
                .stroke(
                    isDragTargeted
                        ? NotchColors.accentPrimary
                        : Color.white.opacity(manager.mode == .idle ? 0.0 : 0.12),
                    lineWidth: isDragTargeted ? 1.5 : 1
                )
            )
            .shadow(
                color: Color.black.opacity(manager.mode == .idle ? 0.0 : 0.55),
                radius: manager.mode.isExpanded ? 18 : 10,
                x: 0,
                y: 8
            )

            Group {
                switch manager.mode {
                case .idle:
                    NotchIdleView(manager: manager)
                case .compact(let activity):
                    NotchCompactView(
                        manager: manager,
                        music: manager.music,
                        productivity: manager.productivity,
                        activity: activity
                    )
                case .expanded:
                    NotchExpandedView(manager: manager)
                }
            }
            .frame(width: shellSize.width, height: shellSize.height)
            .padding(.horizontal, earRadius)
            .clipShape(
                NotchShellShape(
                    topEarRadius: earRadius,
                    bottomCornerRadius: bottomRadius
                )
            )
        }
        .frame(width: totalWidth, height: shellSize.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleFileDrop(providers: providers)
        }
        .animation(transitionAnimation, value: manager.mode)
        .animation(transitionAnimation, value: manager.homeSubView)
        .animation(transitionAnimation, value: manager.activeTab)
        .preferredColorScheme(.dark)
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !matching.isEmpty else { return false }

        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    manager.addDroppedFiles([url])
                }
            }
        }
        return true
    }
}
