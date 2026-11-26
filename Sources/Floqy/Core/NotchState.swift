import SwiftUI

/// Actionable alert pills displayed just below the hardware camera notch.
enum NotchAlert: Equatable, Hashable {
    case pomodoroComplete(durationMinutes: Int)
    case meetingStarting(eventId: String, title: String, provider: String, url: URL)
    case aiFinished(agent: AIAgentKind)
    case headphonesConnected(name: String, batteryPercent: Int?, isAirPods: Bool)
    case chargingConnected(batteryPercent: Int, etaText: String?)
}

/// Represents the four visual states of the Floqy notch window.
enum NotchMode: Equatable, Hashable {
    case idle
    case compact(CompactActivity)
    case alert(NotchAlert)
    case expanded

    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }

    var isCompact: Bool {
        if case .compact = self { return true }
        return false
    }

    var isAlert: Bool {
        if case .alert = self { return true }
        return false
    }

    static func resolvedCollapsedMode(
        activeAlert: NotchAlert?,
        hasMeetingHeadsUp: Bool,
        pomodoroRunning: Bool,
        pomodoroPaused: Bool,
        showPausedPomodoroInNotch: Bool,
        hasActiveAIWork: Bool = false,
        isMemoryAlertActive: Bool = false,
        isMusicPlaying: Bool
    ) -> NotchMode {
        if let activeAlert {
            return .alert(activeAlert)
        }
        if hasMeetingHeadsUp {
            return .compact(.meeting)
        }
        if pomodoroRunning {
            return .compact(.pomodoro)
        }
        if hasActiveAIWork {
            return .compact(.ai)
        }
        if isMemoryAlertActive {
            return .compact(.memory)
        }
        if isMusicPlaying {
            return .compact(.music)
        }
        if pomodoroPaused && showPausedPomodoroInNotch {
            return .compact(.pomodoro)
        }
        return .idle
    }
}

/// Live activities that can be surfaced in the Compact notch wings.
enum CompactActivity: String, CaseIterable, Identifiable, Hashable {
    case music
    case meeting
    case pomodoro
    case ai
    case memory

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .music: return "Music"
        case .meeting: return "Meeting"
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
        case .files: return "Shelf"
        case .notes: return "Focus"
        case .clipboard: return "Board"
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

/// Sub-view displayed inside the Home tab.
enum HomeSubView: String, CaseIterable, Equatable, Hashable {
    case overview
    case calendar

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .calendar: return "Calendar"
        }
    }
}

/// Selectable visual appearance for the idle notch mini-chin.
enum IdleAppearance: String, CaseIterable, Identifiable, Hashable {
    case off
    case eyes
    case cat
    case dog
    case wave
    case horizon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .eyes: return "Eyes"
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .wave: return "Wave"
        case .horizon: return "Horizon"
        }
    }

    var isVisible: Bool {
        self != .off
    }

    var isSideWing: Bool {
        self == .cat || self == .dog
    }

    var usesBottomChin: Bool {
        isVisible && !isSideWing
    }
}

/// Horizontal footprint of the idle mini-chin beneath the hardware camera.
enum IdleNotchWidth: String, CaseIterable, Identifiable, Hashable {
    case compact
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "Compact"
        case .full: return "Full"
        }
    }
}

/// Selectable visual themes for Floqy's notch shell, cards, and custom background image.
enum NotchThemePreset: String, CaseIterable, Identifiable, Hashable {
    case obsidian
    case midnight
    case pureWhite
    case sakuraBlush
    case roseVelvet
    case wallpaperDark
    case wallpaperLight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .obsidian: return "Obsidian"
        case .midnight: return "Midnight"
        case .pureWhite: return "Pure White"
        case .sakuraBlush: return "Sakura Blush"
        case .roseVelvet: return "Rose Velvet"
        case .wallpaperDark: return "Wallpaper (Dark)"
        case .wallpaperLight: return "Wallpaper (Light)"
        }
    }

    var isLight: Bool {
        self == .pureWhite || self == .sakuraBlush || self == .wallpaperLight
    }

    var usesWallpaper: Bool {
        self == .wallpaperDark || self == .wallpaperLight
    }

    static func resolved(for mode: NotchMode, selected: NotchThemePreset) -> NotchThemePreset {
        mode.isExpanded ? selected : .obsidian
    }
}

/// Strategy for selecting which macOS display hosts the Floqy notch panel.
enum DisplayPreference: String, CaseIterable, Identifiable, Hashable {
    case builtInNotch
    case primary
    case followCursor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtInNotch: return "Built-in Notch Display"
        case .primary: return "Primary Display"
        case .followCursor: return "Follow Cursor"
        }
    }
}
