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
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("Floqy", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
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

    func chooseVaultFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.prompt = "Select Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmark: Data
            do {
                bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                bookmark = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }

            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            UserDefaults.standard.set(url.lastPathComponent, forKey: Self.vaultNameKey)
            vaultName = url.lastPathComponent
            lastError = nil
            loadRecentNotes()
        } catch {
            lastError = "Could not save folder access: \(error.localizedDescription)"
        }
    }

    func disconnectVault() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        UserDefaults.standard.removeObject(forKey: Self.vaultNameKey)
        vaultName = nil
        lastSavedSummary = nil
        lastError = nil
        loadRecentNotes()
    }

    func openActiveNotesFolder() {
        if let vaultURL = resolveVaultURL() {
            let didStartScope = vaultURL.startAccessingSecurityScopedResource()
            defer {
                if didStartScope {
                    vaultURL.stopAccessingSecurityScopedResource()
                }
            }
            NSWorkspace.shared.open(vaultURL)
            return
        }

        let localDir = Self.localNotesDirectory
        try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(localDir)
    }

    @discardableResult
    func appendNote(body: String, tags: [String]) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Write a note first."
            return false
        }

        let scopedVault = resolveVaultURL()
        let baseURL = scopedVault ?? Self.localNotesDirectory
        let didStartScope = scopedVault?.startAccessingSecurityScopedResource() ?? false
        defer {
            if didStartScope {
                scopedVault?.stopAccessingSecurityScopedResource()
            }
        }

        let now = Date()
        let relativePath = ObsidianLogic.resolveRelativePath(for: target, date: now)
        guard let fileURL = ObsidianLogic.safeTargetURL(vaultURL: baseURL, relativePath: relativePath) else {
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
            loadRecentNotes()
            return true
        } catch {
            lastError = "Write failed: \(error.localizedDescription)"
            return false
        }
    }

    func loadRecentNotes() {
        let scopedVault = resolveVaultURL()
        let baseURL = scopedVault ?? Self.localNotesDirectory
        let didStartScope = scopedVault?.startAccessingSecurityScopedResource() ?? false
        defer {
            if didStartScope {
                scopedVault?.stopAccessingSecurityScopedResource()
            }
        }

        let relativePath = ObsidianLogic.resolveRelativePath(for: target, date: Date())
        guard let fileURL = ObsidianLogic.safeTargetURL(vaultURL: baseURL, relativePath: relativePath),
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

    private func resolveVaultURL() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            return nil
        }

        var isStale = false
        if let scoped = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return scoped
        }

        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
