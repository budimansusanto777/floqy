import SwiftUI

/// Shared card container with verified dark surface and border contrast.
struct NotchCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(NotchColors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(NotchColors.cardBorder, lineWidth: 1)
                    )
            )
    }
}

private struct PhaseBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(NotchColors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(NotchColors.cardBorder, lineWidth: 1))
            )
    }
}

// MARK: - 1. Home Tab (Media + Calendar + Compact Wing Previews)

struct HomeTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        HStack(spacing: 10) {
            NotchCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Now Playing", systemImage: "music.note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 1")
                    }

                    Text("Spotify & Apple Music playback controls, artwork, and seek bar sync here.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Button {
                        manager.showCompact(.music)
                    } label: {
                        Label("Preview Music Wing", systemImage: "music.note")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchColors.accentPrimary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                }
            }

            VStack(spacing: 8) {
                NotchCard {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Google Calendar", systemImage: "calendar")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NotchColors.textPrimary)
                            Spacer()
                            PhaseBadge(label: "Phase 1")
                        }

                        Text("Upcoming EventKit meetings with countdowns and 1-click Join links.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(NotchColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 8) {
                    wingTile(title: "Music", icon: "music.note", color: NotchColors.accentPrimary) {
                        manager.showCompact(.music)
                    }
                    wingTile(title: "Focus", icon: "timer", color: NotchColors.statusAlert) {
                        manager.showCompact(.pomodoro)
                    }
                    wingTile(title: "System", icon: "cpu", color: NotchColors.statusWarning) {
                        manager.selectTab(.system)
                    }
                }
                .frame(height: 38)
            }
        }
    }

    private func wingTile(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(NotchColors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NotchColors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 10))
    }
}

// MARK: - 2. Files Smart Tray Tab

struct FilesTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Files Smart Tray", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    if !manager.droppedFileNames.isEmpty {
                        Button("Clear All") {
                            manager.clearDroppedFiles()
                        }
                        .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 6))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchColors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                    }
                    PhaseBadge(label: "Phase 2")
                }

                if manager.droppedFileNames.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tray is empty.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(NotchColors.textPrimary)
                        Text("Drag any file from Finder onto the notch to stage it here. Native AirDrop, compression, and OCR arrive in Phase 2.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(NotchColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(Array(manager.droppedFileNames.enumerated()), id: \.offset) { index, name in
                                HStack {
                                    Image(systemName: "doc")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(NotchColors.accentPrimary)
                                    Text(name)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(NotchColors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        manager.removeDroppedFile(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(NotchColors.textSecondary)
                                            .frame(width: 18, height: 18)
                                    }
                                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 5))
                                    .accessibilityLabel("Remove \(name)")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(NotchColors.cardBorder, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }

                    Text("AirDrop, WebP compression, and offline OCR actions unlock in Phase 2.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - 3. Notes & Todo Tab

struct NotesTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        HStack(spacing: 10) {
            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Obsidian Quick Note", systemImage: "note.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 2")
                    }
                    Text("Append quick thoughts and tags straight into your security-scoped Obsidian Vault.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }

            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Focus Timer & Todo", systemImage: "timer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 1")
                    }
                    Text("Persistent tasks and live Pomodoro countdown synced with the Compact wing.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        manager.showCompact(.pomodoro)
                    } label: {
                        Label("Preview Focus Wing", systemImage: "timer")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchColors.statusAlert)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                }
            }
        }
    }
}

// MARK: - 4. Copy (Clipboard Manager) Tab

struct ClipboardTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Copy Windows — Clipboard History", systemImage: "doc.on.clipboard")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    Text("⌘⇧V")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(NotchColors.textSecondary)
                    PhaseBadge(label: "Phase 2")
                }
                Text("Lightweight NSPasteboard watcher with auto-type badges (Code, URL, Text, Image), search, pinning, and 1-click AI explanation.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - 5. AI Agent Tab

struct AITabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "command")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchColors.accentPrimary)
                    Text("Floqy AI Agent")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(NotchColors.textPrimary)
                    Spacer()
                    PhaseBadge(label: "Phase 4")
                }

                Text("BYOK (Gemini, OpenAI, Claude) and local Ollama support with Keychain storage, cross-module context, and background notch execution.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Button {
                    manager.showCompact(.ai)
                } label: {
                    Label("Preview AI Wing", systemImage: "command")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchColors.accentPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                }
                .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
            }
        }
    }
}

// MARK: - 6. System Tab (Memory Monitor + Dev Live Activity)

struct SystemTabView: View {
    @ObservedObject var manager: NotchManager

    var body: some View {
        HStack(spacing: 10) {
            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Memory Pressure", systemImage: "memorychip")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 3")
                    }
                    Text("Kernel RAM stats (App, Wired, Compressed, Swap), top consumers with 1-click Kill, and Purge.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        manager.showCompact(.memory)
                    } label: {
                        Label("Preview RAM Wing", systemImage: "memorychip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchColors.statusWarning)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                }
            }

            NotchCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Dev Live Activity & Ports", systemImage: "hammer.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchColors.textPrimary)
                        Spacer()
                        PhaseBadge(label: "Phase 3")
                    }
                    Text("Active local port scanner (:3000, :5173, :5432) and companion `floqy` CLI build updates.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        manager.showCompact(.dev)
                    } label: {
                        Label("Preview Build Wing", systemImage: "hammer.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchColors.accentPrimary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(NotchInteractiveButtonStyle(cornerRadius: 7))
                }
            }
        }
    }
}
