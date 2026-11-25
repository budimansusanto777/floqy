import SwiftUI

/// Full expanded notch hub with camera-safe header and 6 symmetrical tabs below the hardware notch.
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
                cameraSafeHeader
                    .frame(height: manager.geometry.notchSafeTopHeight)

                tabBar
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(NotchColors.cardBorder)
                            .frame(height: 1)
                    }

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 8)
            }
            .padding(.top, 0)
            .padding(.bottom, 10)
            .padding(.horizontal, 14)

            if let toast = manager.toastMessage {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchColors.notchBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(NotchColors.accentPrimary))
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onKeyPress(.escape) {
            manager.collapse()
            return .handled
        }
    }

    private var cameraSafeHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Floqy")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchColors.textSecondary)

                if manager.activeTab == .home {
                    homeSubViewToggle
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: manager.geometry.notchCenterGapWidth)

            HStack {
                Spacer(minLength: 0)
                Button {
                    manager.collapse()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                .accessibilityLabel("Collapse Notch")
                .help("Collapse Notch (Esc)")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var homeSubViewToggle: some View {
        HStack(spacing: 2) {
            ForEach(HomeSubView.allCases, id: \.self) { subView in
                let isSelected = manager.homeSubView == subView
                Button {
                    manager.setHomeSubView(subView)
                } label: {
                    Text(subView.title)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? NotchColors.textPrimary : NotchColors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5, isSelected: isSelected))
                .accessibilityLabel("\(subView.title) mode")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(NotchColors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(NotchColors.cardBorder, lineWidth: 1)
                )
        )
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(Array(NotchTab.leftTabs.enumerated()), id: \.element) { offset, tab in
                    tabButton(tab, shortcutIndex: offset + 1)
                }
            }

            Spacer(minLength: 10)

            HStack(spacing: 3) {
                ForEach(Array(NotchTab.rightTabs.enumerated()), id: \.element) { offset, tab in
                    tabButton(tab, shortcutIndex: offset + 4)
                }
            }
        }
    }

    private func tabButton(_ tab: NotchTab, shortcutIndex: Int) -> some View {
        let isSelected = manager.activeTab == tab
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7, isSelected: isSelected))
        .keyboardShortcut(KeyEquivalent(Character("\(shortcutIndex)")), modifiers: .command)
        .accessibilityLabel("\(tab.title) tab")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var tabContent: some View {
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
            AITabView(manager: manager)
        case .system:
            SystemTabView(manager: manager, system: manager.system)
        }
    }
}
