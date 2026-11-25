import AppKit
import Combine
import Foundation

/// Tracks AI agent hook notifications, installs official JSON hooks non-destructively, and summarizes today's local usage.
@MainActor
final class AIService: ObservableObject {
    @Published private(set) var workingAgent: AIAgentKind?
    @Published private(set) var hookStatus: [AIAgentKind: Bool] = [:]
    @Published private(set) var recentCompletions: [AICompletionRecord] = []
    @Published private(set) var claudeUsageToday: LocalTokenUsageSummary?

    var onAgentFinished: ((AIAgentKind) -> Void)?
    var onStateChanged: (() -> Void)?

    private struct AIActivityStorage: Codable {
        let dayKey: String
        let counts: [String: Int]
        let recentCompletions: [AICompletionRecord]
    }

    private struct ClaudeUsageCacheEntry {
        let modified: Date
        let size: Int
        let summary: LocalTokenUsageSummary
    }

    private var workingTimeoutTask: Task<Void, Never>?
    private let activityStorageURL: URL
    private var dailyCounts: [String: Int] = [:]
    private var dailyCountDayKey: String = CalendarLogic.dayKey(for: Date())
    private var claudeFileCache: [String: ClaudeUsageCacheEntry] = [:]

    init() {
        self.activityStorageURL = FileManager.floqySupportDirectory
            .appendingPathComponent("ai_activity.json")
    }

    func start() {
        loadTodayActivity()
        refreshHookStatus()
        refreshClaudeLocalUsage()
    }

    func stop() {
        workingTimeoutTask?.cancel()
        workingTimeoutTask = nil
    }

    func todayCount(for agent: AIAgentKind) -> Int {
        guard CalendarLogic.dayKey(for: Date()) == dailyCountDayKey else { return 0 }
        return dailyCounts[agent.rawValue, default: 0]
    }

    func handleEvent(_ event: AIAgentEvent) {
        switch event.state {
        case .working:
            workingAgent = event.agent
            scheduleWorkingSafetyClear()
            onStateChanged?()

        case .done:
            workingTimeoutTask?.cancel()
            if workingAgent == event.agent {
                workingAgent = nil
            }
            syncDayIfNeeded()
            dailyCounts[event.agent.rawValue, default: 0] += 1
            let startOfDay = Calendar.current.startOfDay(for: Date())
            var updated = recentCompletions.filter { $0.completedAt >= startOfDay }
            updated.insert(AICompletionRecord(agent: event.agent), at: 0)
            recentCompletions = Array(updated.prefix(30))
            saveActivity()

            if event.agent == .claudeCode {
                refreshClaudeLocalUsage()
            }

            onAgentFinished?(event.agent)
            onStateChanged?()
        }
    }

    func refreshHookStatus() {
        var next: [AIAgentKind: Bool] = [:]
        for agent in AIAgentKind.allCases where agent.supportsHook {
            guard let url = AIActivityLogic.configFileURL(for: agent),
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                next[agent] = false
                continue
            }
            next[agent] = AIActivityLogic.isHookInstalled(in: content, for: agent)
        }
        hookStatus = next
    }

    func toggleHook(for agent: AIAgentKind) -> String {
        guard agent.supportsHook, let url = AIActivityLogic.configFileURL(for: agent) else {
            return "\(agent.displayName) does not support hooks"
        }

        let existing: String?
        if FileManager.default.fileExists(atPath: url.path) {
            guard let loaded = try? String(contentsOf: url, encoding: .utf8) else {
                return "Could not read \(url.lastPathComponent)"
            }
            existing = loaded
        } else {
            existing = nil
        }

        let currentlyInstalled = AIActivityLogic.isHookInstalled(in: existing, for: agent)
        let updatedJSON: String? = currentlyInstalled
            ? AIActivityLogic.removeHook(from: existing, for: agent)
            : AIActivityLogic.upsertHook(in: existing, for: agent)

        guard let updatedJSON else {
            return "Skipped update: invalid JSON in \(url.lastPathComponent)"
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try updatedJSON.write(to: url, atomically: true, encoding: .utf8)
            refreshHookStatus()
            return currentlyInstalled
                ? "Disconnected \(agent.displayName) hook"
                : "Connected \(agent.displayName) hook"
        } catch {
            return "Failed to update \(url.lastPathComponent)"
        }
    }

    func openAgentApp(_ agent: AIAgentKind) {
        let candidateApps: [String]
        switch agent {
        case .antigravity:
            candidateApps = ["/Applications/Antigravity.app", "\(NSHomeDirectory())/Applications/Antigravity.app"]
        case .claudeDesktop:
            candidateApps = ["/Applications/Claude.app", "\(NSHomeDirectory())/Applications/Claude.app"]
        case .geminiCLI, .claudeCode:
            candidateApps = ["/System/Applications/Utilities/Terminal.app", "/Applications/iTerm.app"]
        }

        for path in candidateApps where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: path),
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }
    }

    func refreshClaudeLocalUsage() {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let cacheSnapshot = claudeFileCache

        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.scanClaudeUsage(in: projectsDir, since: startOfDay, cache: cacheSnapshot)
            }.value

            guard let self else { return }
            self.claudeFileCache = result.updatedCache
            self.claudeUsageToday = result.summary.totalTokens > 0 ? result.summary : nil
        }
    }

    private nonisolated static func scanClaudeUsage(
        in projectsDir: URL,
        since startOfDay: Date,
        cache: [String: ClaudeUsageCacheEntry]
    ) -> (summary: LocalTokenUsageSummary, updatedCache: [String: ClaudeUsageCacheEntry]) {
        guard FileManager.default.fileExists(atPath: projectsDir.path),
              let enumerator = FileManager.default.enumerator(
                  at: projectsDir,
                  includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return (.empty, [:])
        }

        var input = 0
        var output = 0
        var read = 0
        var write = 0
        var cost = 0.0
        var nextCache: [String: ClaudeUsageCacheEntry] = [:]

        while let item = enumerator.nextObject() {
            guard let fileURL = item as? URL, fileURL.pathExtension == "jsonl" else { continue }
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modified = values?.contentModificationDate
            if let modified, modified < startOfDay {
                continue
            }
            let fileSize = values?.fileSize ?? -1
            let path = fileURL.path

            let fileSummary: LocalTokenUsageSummary
            if let modified,
               fileSize >= 0,
               let cached = cache[path],
               cached.modified == modified,
               cached.size == fileSize {
                fileSummary = cached.summary
                nextCache[path] = cached
            } else {
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                fileSummary = AIActivityLogic.parseClaudeJSONLUsage(jsonlContent: content, since: startOfDay)
                if let modified, fileSize >= 0 {
                    nextCache[path] = ClaudeUsageCacheEntry(modified: modified, size: fileSize, summary: fileSummary)
                }
            }

            input += fileSummary.inputTokens
            output += fileSummary.outputTokens
            read += fileSummary.cacheReadTokens
            write += fileSummary.cacheWriteTokens
            cost += fileSummary.estimatedCostUSD
        }

        let summary = LocalTokenUsageSummary(
            inputTokens: input,
            outputTokens: output,
            cacheReadTokens: read,
            cacheWriteTokens: write,
            estimatedCostUSD: cost
        )
        return (summary, nextCache)
    }

    private func scheduleWorkingSafetyClear() {
        workingTimeoutTask?.cancel()
        workingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(600))
            guard !Task.isCancelled, let self else { return }
            self.workingAgent = nil
            self.onStateChanged?()
        }
    }

    private func syncDayIfNeeded() {
        let todayKey = CalendarLogic.dayKey(for: Date())
        guard dailyCountDayKey != todayKey else { return }
        dailyCountDayKey = todayKey
        dailyCounts = [:]
        recentCompletions = []
    }

    private func loadTodayActivity() {
        let todayKey = CalendarLogic.dayKey(for: Date())
        dailyCountDayKey = todayKey
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let data = try? Data(contentsOf: activityStorageURL) else { return }

        if let storage = try? JSONDecoder().decode(AIActivityStorage.self, from: data) {
            if storage.dayKey == todayKey {
                dailyCounts = storage.counts
                recentCompletions = Array(storage.recentCompletions.filter { $0.completedAt >= startOfDay }.prefix(30))
            } else {
                dailyCounts = [:]
                recentCompletions = []
            }
            return
        }

        if let legacy = try? JSONDecoder().decode([AICompletionRecord].self, from: data) {
            let todayRecords = legacy.filter { $0.completedAt >= startOfDay }
            var counts: [String: Int] = [:]
            for record in todayRecords {
                counts[record.agent.rawValue, default: 0] += 1
            }
            dailyCounts = counts
            recentCompletions = Array(todayRecords.prefix(30))
        }
    }

    private func saveActivity() {
        let dir = activityStorageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload = AIActivityStorage(
            dayKey: dailyCountDayKey,
            counts: dailyCounts,
            recentCompletions: recentCompletions
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: activityStorageURL, options: .atomic)
    }
}
