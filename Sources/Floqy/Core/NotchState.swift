import SwiftUI

/// Represents the three visual states of the Floqy notch window.
enum NotchMode: Equatable, Hashable {
    case idle
    case compact(CompactActivity)
    case expanded

    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }

    var isCompact: Bool {
        if case .compact = self { return true }
        return false
    }
}

/// Live activities that can be surfaced in the Compact notch wings.
enum CompactActivity: String, CaseIterable, Identifiable, Hashable {
    case music
    case dev
    case pomodoro
    case ai
    case memory

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .music: return "Music"
        case .dev: return "Dev Build"
        case .pomodoro: return "Pomodoro"
        case .ai: return "AI Agent"
        case .memory: return "Memory"
        }
    }
}

/// Six symmetrical tabs arranged around the hardware camera notch.
enum NotchTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case files
    case notes
    case clipboard
    case ai
    case system

    var id: String { rawValue }

    static let leftTabs: [NotchTab] = [.home, .files, .notes]
    static let rightTabs: [NotchTab] = [.clipboard, .ai, .system]

    var title: String {
        switch self {
        case .home: return "Home"
        case .files: return "Files"
        case .notes: return "Notes & Todo"
        case .clipboard: return "Copy"
        case .ai: return "AI"
        case .system: return "System"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "tray.and.arrow.down.fill"
        case .notes: return "note.text"
        case .clipboard: return "doc.on.clipboard.fill"
        case .ai: return "command"
        case .system: return "cpu"
        }
    }
}
