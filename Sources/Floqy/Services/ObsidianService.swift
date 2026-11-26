import AppKit
import Combine
import Foundation

/// Appends quick Markdown notes locally by default, or to a linked Obsidian Vault folder.
@MainActor
final class ObsidianService: ObservableObject {
    private static let bookmarkKey = "floqy.obsidian.vaultBookmark"
    private static let vaultNameKey = "floqy.obsidian.vaultName"
    private static let targetKey = "floqy.obsidian.target"

    static var localNotesDirectory: URL {
        FileManager.floqySupportDirectory.appendingPathComponent("Notes", isDirectory: true)
    }

    @Published var target: ObsidianNoteTarget {
        didSet {
            UserDefaults.standard.set(target.rawValue, forKey: Self.targetKey)
            loadRecentNotes()
        }
    }

    @Published private(set) var vaultName: String?
    @Published private(set) var recentNotes: [String] = []
    @Published private(set) var lastSavedSummary: String?
    @Published private(set) var lastError: String?

    private var feedbackClearTask: Task<Void, Never>?
    private weak var activeOpenPanel: NSOpenPanel?

    var isVaultConfigured: Bool {
        vaultName != nil && UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil
    }

    var storageLabel: String {
        vaultName ?? "Quick Notes"
    }

    init() {
        let rawTarget = UserDefaults.standard.string(forKey: Self.targetKey) ?? ObsidianNoteTarget.daily.rawValue
        self.target = ObsidianNoteTarget(rawValue: rawTarget) ?? .daily
        self.vaultName = UserDefaults.standard.string(forKey: Self.vaultNameKey)
        loadRecentNotes()
    }

    func chooseVaultFolder(onComplete: (() -> Void)? = nil) {
        if let activeOpenPanel {
            NSApp.activate(ignoringOtherApps: true)
            activeOpenPanel.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.prompt = "Select Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        activeOpenPanel = panel

        panel.begin { [weak self] response in
            Task { @MainActor [weak self] in
                defer {
                    self?.activeOpenPanel = nil
                    onComplete?()
                }
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    let bookmark = try Self.makeBookmark(for: url)
                    UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
                    UserDefaults.standard.set(url.lastPathComponent, forKey: Self.vaultNameKey)
                    self.vaultName = url.lastPathComponent
                    self.lastError = nil
                    self.loadRecentNotes()
                } catch {
                    self.lastError = "Could not save folder access: \(error.localizedDescription)"
                }
            }
        }
    }

    func disconnectVault() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        UserDefaults.standard.removeObject(forKey: Self.vaultNameKey)
        vaultName = nil
        clearTransientFeedback()
        loadRecentNotes()
    }

    func clearTransientFeedback() {
        feedbackClearTask?.cancel()
        lastSavedSummary = nil
        lastError = nil
    }

    func openActiveNotesFolder() {
        guard let base = activeBaseDirectory() else {
            lastError = "Vault folder unavailable. Re-select your folder."
            return
        }
        let didStartScope = base.isScoped ? base.url.startAccessingSecurityScopedResource() : false
        defer {
            if didStartScope {
                base.url.stopAccessingSecurityScopedResource()
            }
        }
        if !base.isScoped {
            try? FileManager.default.createDirectory(at: base.url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(base.url)
    }

    @discardableResult
    func appendNote(body: String, tags: [String]) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Write a note first."
            return false
        }

        guard let base = activeBaseDirectory() else {
            lastError = "Vault folder unavailable. Re-select your folder."
            return false
        }
        let didStartScope = base.isScoped ? base.url.startAccessingSecurityScopedResource() : false
        defer {
            if didStartScope {
                base.url.stopAccessingSecurityScopedResource()
            }
        }

        let now = Date()
        let relativePath = ObsidianLogic.resolveRelativePath(for: target, date: now)
        guard let fileURL = ObsidianLogic.safeTargetURL(vaultURL: base.url, relativePath: relativePath) else {
            lastError = "Invalid note path."
            return false
        }

        let entryLine = ObsidianLogic.formatMarkdownEntry(body: trimmed, tags: tags, timestamp: now)

        do {
            let parentDir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                var existing = try String(contentsOf: fileURL, encoding: .utf8)
                if !existing.isEmpty && !existing.hasSuffix("\n") {
                    existing.append("\n")
                }
                existing.append(entryLine)
                try existing.write(to: fileURL, atomically: true, encoding: .utf8)
            } else {
                let heading = "# \(fileURL.deletingPathExtension().lastPathComponent)\n\n"
                try (heading + entryLine).write(to: fileURL, atomically: true, encoding: .utf8)
            }

            lastError = nil
            lastSavedSummary = "Saved to \(relativePath)"
            feedbackClearTask?.cancel()
            feedbackClearTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                self?.lastSavedSummary = nil
            }
            loadRecentNotes()
            return true
        } catch {
            lastError = "Write failed: \(error.localizedDescription)"
            return false
        }
    }

    func loadRecentNotes() {
        guard let base = activeBaseDirectory() else {
            lastError = "Vault folder unavailable. Re-select your folder."
            recentNotes = []
            return
        }
        let didStartScope = base.isScoped ? base.url.startAccessingSecurityScopedResource() : false
        defer {
            if didStartScope {
                base.url.stopAccessingSecurityScopedResource()
            }
        }

        let relativePath = ObsidianLogic.resolveRelativePath(for: target, date: Date())
        guard let fileURL = ObsidianLogic.safeTargetURL(vaultURL: base.url, relativePath: relativePath),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            recentNotes = []
            return
        }

        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") }
        recentNotes = Array(lines.suffix(3).reversed())
    }

    private func activeBaseDirectory() -> (url: URL, isScoped: Bool)? {
        if let scoped = resolveVaultURL() {
            return (scoped, true)
        }
        if isVaultConfigured {
            return nil
        }
        return (Self.localNotesDirectory, false)
    }

    private static func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
    }

    private func resolveVaultURL() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            return nil
        }

        var isStale = false
        let resolved = (try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )) ?? (try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ))

        if let resolved, isStale {
            let accessed = resolved.startAccessingSecurityScopedResource()
            defer {
                if accessed { resolved.stopAccessingSecurityScopedResource() }
            }
            if let refreshed = try? Self.makeBookmark(for: resolved) {
                UserDefaults.standard.set(refreshed, forKey: Self.bookmarkKey)
            }
        }
        return resolved
    }
}
