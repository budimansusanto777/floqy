import Foundation

enum AIAgentKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case antigravity
    case geminiCLI
    case claudeCode
    case claudeDesktop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .geminiCLI: return "Gemini CLI"
        case .claudeCode: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        }
    }

    var shortName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .geminiCLI: return "Gemini"
        case .claudeCode: return "Claude"
        case .claudeDesktop: return "Claude"
        }
    }

    var subtitle: String {
        switch self {
        case .antigravity: return "~/.gemini/config/hooks.json"
        case .geminiCLI: return "~/.gemini/settings.json"
        case .claudeCode: return "~/.claude/settings.json"
        case .claudeDesktop: return "Quick launch"
        }
    }

    var supportsHook: Bool {
        self != .claudeDesktop
    }
}

enum AIAgentEventState: String, Equatable {
    case working
    case done
}

struct AIAgentEvent: Equatable {
    let agent: AIAgentKind
    let state: AIAgentEventState
}

struct AICompletionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let agent: AIAgentKind
    let completedAt: Date

    init(id: UUID = UUID(), agent: AIAgentKind, completedAt: Date = Date()) {
        self.id = id
        self.agent = agent
        self.completedAt = completedAt
    }
}

struct LocalTokenUsageSummary: Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int
    let estimatedCostUSD: Double

    static let empty = LocalTokenUsageSummary(
        inputTokens: 0,
        outputTokens: 0,
        cacheReadTokens: 0,
        cacheWriteTokens: 0,
        estimatedCostUSD: 0
    )

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
        if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    static func formatUSD(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }
}

/// Pure helpers for `floqy://` hook URL parsing, non-destructive JSON hook merging, and local JSONL usage stats.
enum AIActivityLogic {
    static let hookName = "floqy-notify"

    static func hookCommand(for agent: AIAgentKind, state: AIAgentEventState) -> String {
        "pgrep -x Floqy >/dev/null 2>&1 && open -g \"floqy://ai?agent=\(agent.rawValue)&state=\(state.rawValue)\" >/dev/null 2>&1; printf '{}'"
    }

    static func parseIncomingURL(_ url: URL) -> AIAgentEvent? {
        guard url.scheme?.lowercased() == "floqy",
              url.host?.lowercased() == "ai",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return nil
        }

        let values = Dictionary(items.compactMap { item -> (String, String)? in
            guard let val = item.value else { return nil }
            return (item.name, val)
        }, uniquingKeysWith: { _, latest in latest })

        guard let rawAgent = values["agent"],
              let agent = AIAgentKind(rawValue: rawAgent),
              let rawState = values["state"],
              let state = AIAgentEventState(rawValue: rawState) else {
            return nil
        }
        return AIAgentEvent(agent: agent, state: state)
    }

    static func configFileURL(for agent: AIAgentKind, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        switch agent {
        case .antigravity:
            return homeDirectory.appendingPathComponent(".gemini/config/hooks.json")
        case .geminiCLI:
            return homeDirectory.appendingPathComponent(".gemini/settings.json")
        case .claudeCode:
            return homeDirectory.appendingPathComponent(".claude/settings.json")
        case .claudeDesktop:
            return nil
        }
    }

    static func isHookInstalled(in jsonString: String?, for agent: AIAgentKind) -> Bool {
        guard agent.supportsHook,
              let root = parseRootDictionary(jsonString) else {
            return false
        }

        switch agent {
        case .antigravity:
            return root[hookName] != nil
        case .geminiCLI:
            return hasHookGroup(in: root, eventKey: "AfterAgent", agent: agent)
                && hasHookGroup(in: root, eventKey: "BeforeAgent", agent: agent)
        case .claudeCode:
            return hasHookGroup(in: root, eventKey: "Stop", agent: agent)
                && hasHookGroup(in: root, eventKey: "UserPromptSubmit", agent: agent)
        case .claudeDesktop:
            return false
        }
    }

    static func upsertHook(in existingJSON: String?, for agent: AIAgentKind) -> String? {
        guard agent.supportsHook,
              var root = parseRootDictionary(existingJSON, allowEmpty: true) else {
            return nil
        }

        switch agent {
        case .antigravity:
            let entry: [String: Any] = [
                "enabled": true,
                "PreInvocation": [
                    ["type": "command", "command": hookCommand(for: .antigravity, state: .working), "timeout": 5]
                ],
                "Stop": [
                    ["type": "command", "command": hookCommand(for: .antigravity, state: .done), "timeout": 5]
                ]
            ]
            root[hookName] = entry

        case .geminiCLI:
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            hooks["BeforeAgent"] = replacingFloqyGroup(
                in: hooks["BeforeAgent"] as? [[String: Any]] ?? [],
                agent: .geminiCLI,
                newGroup: [
                    "matcher": "*",
                    "hooks": [[
                        "name": hookName,
                        "type": "command",
                        "command": hookCommand(for: .geminiCLI, state: .working)
                    ]]
                ]
            )
            hooks["AfterAgent"] = replacingFloqyGroup(
                in: hooks["AfterAgent"] as? [[String: Any]] ?? [],
                agent: .geminiCLI,
                newGroup: [
                    "matcher": "*",
                    "hooks": [[
                        "name": hookName,
                        "type": "command",
                        "command": hookCommand(for: .geminiCLI, state: .done)
                    ]]
                ]
            )
            root["hooks"] = hooks

        case .claudeCode:
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            hooks["UserPromptSubmit"] = replacingFloqyGroup(
                in: hooks["UserPromptSubmit"] as? [[String: Any]] ?? [],
                agent: .claudeCode,
                newGroup: [
                    "hooks": [[
                        "type": "command",
                        "command": hookCommand(for: .claudeCode, state: .working)
                    ]]
                ]
            )
            hooks["Stop"] = replacingFloqyGroup(
                in: hooks["Stop"] as? [[String: Any]] ?? [],
                agent: .claudeCode,
                newGroup: [
                    "hooks": [[
                        "type": "command",
                        "command": hookCommand(for: .claudeCode, state: .done)
                    ]]
                ]
            )
            root["hooks"] = hooks

        case .claudeDesktop:
            return nil
        }

        return serializeJSON(root)
    }

    static func removeHook(from existingJSON: String?, for agent: AIAgentKind) -> String? {
        guard agent.supportsHook,
              var root = parseRootDictionary(existingJSON, allowEmpty: true) else {
            return nil
        }

        switch agent {
        case .antigravity:
            root.removeValue(forKey: hookName)

        case .geminiCLI:
            if var hooks = root["hooks"] as? [String: Any] {
                for key in ["BeforeAgent", "AfterAgent"] {
                    let filtered = stripFloqyGroups(in: hooks[key] as? [[String: Any]] ?? [], agent: .geminiCLI)
                    if filtered.isEmpty {
                        hooks.removeValue(forKey: key)
                    } else {
                        hooks[key] = filtered
                    }
                }
                if hooks.isEmpty {
                    root.removeValue(forKey: "hooks")
                } else {
                    root["hooks"] = hooks
                }
            }

        case .claudeCode:
            if var hooks = root["hooks"] as? [String: Any] {
                for key in ["UserPromptSubmit", "Stop"] {
                    let filtered = stripFloqyGroups(in: hooks[key] as? [[String: Any]] ?? [], agent: .claudeCode)
                    if filtered.isEmpty {
                        hooks.removeValue(forKey: key)
                    } else {
                        hooks[key] = filtered
                    }
                }
                if hooks.isEmpty {
                    root.removeValue(forKey: "hooks")
                } else {
                    root["hooks"] = hooks
                }
            }

        case .claudeDesktop:
            return nil
        }

        return serializeJSON(root)
    }

    static func parseClaudeJSONLUsage(jsonlContent: String, since: Date) -> LocalTokenUsageSummary {
        var input = 0
        var output = 0
        var cacheRead = 0
        var cacheWrite = 0
        var cost = 0.0

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        for line in jsonlContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  trimmed.contains("\"usage\""),
                  let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestampString = obj["timestamp"] as? String else {
                continue
            }

            let parsedDate = fractionalFormatter.date(from: timestampString) ?? standardFormatter.date(from: timestampString)
            guard let entryDate = parsedDate, entryDate >= since,
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else {
                continue
            }

            let inTok = usage["input_tokens"] as? Int ?? 0
            let outTok = usage["output_tokens"] as? Int ?? 0
            let readTok = usage["cache_read_input_tokens"] as? Int ?? 0
            let writeTok = usage["cache_creation_input_tokens"] as? Int ?? 0

            input += inTok
            output += outTok
            cacheRead += readTok
            cacheWrite += writeTok

            let model = (message["model"] as? String ?? "").lowercased()
            let (inRate, outRate, readRate, writeRate): (Double, Double, Double, Double) = if model.contains("opus") {
                (15.0, 75.0, 1.5, 18.75)
            } else if model.contains("haiku") {
                (0.8, 4.0, 0.08, 1.0)
            } else {
                // Default Sonnet pricing per 1M tokens
                (3.0, 15.0, 0.3, 3.75)
            }

            cost += (Double(inTok) * inRate
                + Double(outTok) * outRate
                + Double(readTok) * readRate
                + Double(writeTok) * writeRate) / 1_000_000.0
        }

        return LocalTokenUsageSummary(
            inputTokens: input,
            outputTokens: output,
            cacheReadTokens: cacheRead,
            cacheWriteTokens: cacheWrite,
            estimatedCostUSD: cost
        )
    }

    // MARK: - Private JSON Helpers

    private static func parseRootDictionary(_ jsonString: String?, allowEmpty: Bool = false) -> [String: Any]? {
        let trimmed = jsonString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return allowEmpty ? [:] : nil
        }
        guard let data = trimmed.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func serializeJSON(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string + "\n"
    }

    private static func hasHookGroup(in root: [String: Any], eventKey: String, agent: AIAgentKind) -> Bool {
        guard let hooks = root["hooks"] as? [String: Any],
              let groups = hooks[eventKey] as? [[String: Any]] else {
            return false
        }
        return groups.contains { isFloqyGroup($0, agent: agent) }
    }

    private static func replacingFloqyGroup(
        in existing: [[String: Any]],
        agent: AIAgentKind,
        newGroup: [String: Any]
    ) -> [[String: Any]] {
        var result = stripFloqyGroups(in: existing, agent: agent)
        result.append(newGroup)
        return result
    }

    private static func stripFloqyGroups(in existing: [[String: Any]], agent: AIAgentKind) -> [[String: Any]] {
        existing.filter { !isFloqyGroup($0, agent: agent) }
    }

    private static func isFloqyGroup(_ group: [String: Any], agent: AIAgentKind) -> Bool {
        guard let handlers = group["hooks"] as? [[String: Any]] else {
            return false
        }
        let marker = "floqy://ai?agent=\(agent.rawValue)"
        return handlers.contains { handler in
            let nameMatch = (handler["name"] as? String) == hookName
            let cmdMatch = (handler["command"] as? String)?.contains(marker) == true
            return nameMatch || cmdMatch
        }
    }
}
