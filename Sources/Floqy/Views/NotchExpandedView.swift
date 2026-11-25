import SwiftUI

/// Expanded notch hub with camera-wing tabs, Settings gear beside System, zero Close button, and 12pt concentric framing.
struct NotchExpandedView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject private var filesTray: FilesTrayService

    init(manager: NotchManager) {
        self.manager = manager
        self.filesTray = manager.filesTray
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                cameraWingTabBar
                    .frame(height: manager.geometry.notchSafeTopHeight)

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 8)
            }
            .padding(.top, 0)
            .padding(.bottom, 12)
            .padding(.horizontal, 12)

            if let toast = manager.toastMessage {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchColors.notchBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(NotchColors.textPrimary))
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onKeyPress(.escape) {
            manager.collapse()
            return .handled
        }
    }

    private var cameraWingTabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(Array(NotchTab.leftTabs.enumerated()), id: \.element) { offset, tab in
                    tabButton(tab, shortcutIndex: offset + 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: manager.geometry.notchCenterGapWidth)

            HStack(spacing: 2) {
                ForEach(Array(NotchTab.rightTabs.enumerated()), id: \.element) { offset, tab in
                    tabButton(tab, shortcutIndex: offset + 4)
                }

                Button {
                    manager.toggleInlineSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: manager.isShowingInlineSettings ? .semibold : .medium))
                        .foregroundStyle(manager.isShowingInlineSettings ? NotchColors.textPrimary : NotchColors.textSecondary)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7, isSelected: manager.isShowingInlineSettings))
                .accessibilityLabel("Settings")
                .help("Notch & Hardware Card Settings")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func tabButton(_ tab: NotchTab, shortcutIndex: Int) -> some View {
        let isSelected = !manager.isShowingInlineSettings && manager.activeTab == tab
        return Button {
            manager.selectTab(tab)
        } label: {
            HStack(spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                if tab == .files && !filesTray.items.isEmpty {
                    Text("\(filesTray.items.count)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NotchColors.notchBackground)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(NotchColors.accentPrimary))
                }
            }
            .foregroundStyle(isSelected ? NotchColors.textPrimary : NotchColors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        }
        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7, isSelected: isSelected))
        .keyboardShortcut(KeyEquivalent(Character("\(shortcutIndex)")), modifiers: .command)
        .accessibilityLabel("\(tab.title) tab")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var tabContent: some View {
        if manager.isShowingInlineSettings {
            InlineSettingsTabView(manager: manager)
        } else {
            switch manager.activeTab {
            case .home:
                HomeTabView(
                    manager: manager,
                    music: manager.music,
                    calendar: manager.calendar,
                    productivity: manager.productivity,
                    system: manager.system
                )
            case .files:
                FilesTabView(
                    manager: manager,
                    filesTray: manager.filesTray
                )
            case .notes:
                NotesTabView(
                    manager: manager,
                    obsidian: manager.obsidian,
                    productivity: manager.productivity
                )
            case .clipboard:
                ClipboardTabView(
                    manager: manager,
                    clipboard: manager.clipboard
                )
            case .ai:
                AITabView(manager: manager, ai: manager.ai)
            case .system:
                SystemTabView(manager: manager, system: manager.system)
            }
        }
    }
}
