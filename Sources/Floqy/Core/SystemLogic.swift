import CryptoKit
import Foundation

enum MemoryPressureLevel: String, Equatable {
    case nominal = "Nominal"
    case warning = "Elevated"
    case critical = "Critical"
}

struct MemorySnapshot: Equatable {
    let totalBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64
    let freeBytes: UInt64

    static let empty = MemorySnapshot(
        totalBytes: 0,
        appBytes: 0,
        wiredBytes: 0,
        compressedBytes: 0,
        swapUsedBytes: 0,
        freeBytes: 0
    )

    var usedBytes: UInt64 {
        min(totalBytes, appBytes &+ wiredBytes &+ compressedBytes)
    }

    var usedPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return min(100, Int((Double(usedBytes) / Double(totalBytes) * 100.0).rounded()))
    }

    var pressureLevel: MemoryPressureLevel {
        if usedPercent >= SystemLogic.ramAlertThresholdPercent {
            return .critical
        }
        if usedPercent >= 75 {
            return .warning
        }
        return .nominal
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
        }
        return "\(bytes / 1_048_576) MB"
    }
}

struct MemoryConsumer: Identifiable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let residentBytes: UInt64
}

struct LocalDevPort: Identifiable, Equatable {
    var id: String { "\(pid)-\(port)" }
    let pid: Int32
    let port: Int
    let processName: String
    let isHTTP: Bool
}

/// Pure parsing and calculation helpers for kernel memory stats, processes, and local dev ports.
enum SystemLogic {
    static let ramAlertThresholdPercent = 85

    static let protectedProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "windowserver",
        "loginwindow",
        "finder",
        "dock",
        "systemuiserver",
        "mds",
        "mds_stores",
        "coreaudiod",
        "bluetoothd",
        "cfprefsd",
        "distnoted",
        "notifyd",
        "floqy"
    ]

    private static let preferredDevPorts: Set<Int> = [
        3000, 3001, 4000, 4200, 4321, 5000, 5173, 5174, 5432, 6379, 8000, 8080, 8081, 8888, 9000, 11434
    ]

    private static let nonHTTPPorts: Set<Int> = [
        5432, 3306, 6379, 27017, 5672, 9092, 11211
    ]

    static func isProtectedProcess(_ name: String) -> Bool {
        let base = (name as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return protectedProcessNames.contains(base)
    }

    static func parseTopMemoryProcesses(
        psOutput: String,
        limit: Int = 5,
        selfPID: Int32 = 0
    ) -> [MemoryConsumer] {
        var consumers: [MemoryConsumer] = []

        for rawLine in psOutput.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format from `ps -Arcwwwxo pid=,rss=,comm=`: "<pid> <rss_kb> <command path...>"
            let parts = trimmed.split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let rssKB = UInt64(parts[1]) else {
                continue
            }

            let commandPath = String(parts[2]).trimmingCharacters(in: .whitespaces)
            let name = (commandPath as NSString).lastPathComponent
            guard pid > 1, pid != selfPID, !name.isEmpty else { continue }

            let isProtected = isProtectedProcess(name)
            guard !isProtected else { continue }

            consumers.append(
                MemoryConsumer(
                    pid: pid,
                    name: name,
                    residentBytes: rssKB * 1024
                )
            )
        }

        let sorted = consumers.sorted { lhs, rhs in
            if lhs.residentBytes != rhs.residentBytes {
                return lhs.residentBytes > rhs.residentBytes
            }
            return lhs.pid < rhs.pid
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    static func parseListeningPorts(lsofOutput: String, limit: Int = 10) -> [LocalDevPort] {
        var currentPID: Int32?
        var currentCommand = "process"
        var seenPorts: Set<Int> = []
        var ports: [LocalDevPort] = []

        for rawLine in lsofOutput.components(separatedBy: .newlines) {
            guard let tag = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())

            switch tag {
            case "p":
                currentPID = Int32(value)
                currentCommand = "process"
            case "c":
                if !value.isEmpty {
                    currentCommand = value
                }
            case "n":
                guard let pid = currentPID,
                      let colonIndex = value.lastIndex(of: ":") else {
                    continue
                }
                let portSlice = value[value.index(after: colonIndex)...]
                guard let port = Int(portSlice),
                      (1024...49151).contains(port),
                      !seenPorts.contains(port) else {
                    continue
                }
                seenPorts.insert(port)
                ports.append(
                    LocalDevPort(
                        pid: pid,
                        port: port,
                        processName: currentCommand,
                        isHTTP: !nonHTTPPorts.contains(port)
                    )
                )
            default:
                continue
            }
        }

        let sorted = ports.sorted { lhs, rhs in
            let lhsPreferred = preferredDevPorts.contains(lhs.port)
            let rhsPreferred = preferredDevPorts.contains(rhs.port)
            if lhsPreferred != rhsPreferred {
                return lhsPreferred && !rhsPreferred
            }
            return lhs.port < rhs.port
        }
        return Array(sorted.prefix(max(0, limit)))
    }
}

struct ReleaseInfo: Equatable {
    let version: String
    let tagName: String
    let releaseURL: URL
    let dmgURL: URL?
    let dmgSHA256: String?
}

/// Validates GitHub Release metadata and compares semantic versions without external dependencies.
enum UpdateLogic {
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/budimansusanto777/floqy/releases/latest")!
    static let releasesPageURL = URL(string: "https://github.com/budimansusanto777/floqy/releases/latest")!

    private struct GitHubReleasePayload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String
            let digest: String?

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
                case digest
            }
        }

        let tagName: String
        let htmlURL: String
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft
            case prerelease
            case assets
        }
    }

    static func currentAppVersion(bundle: Bundle = .main) -> String {
        if let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            let clean = normalizedVersion(raw)
            if !clean.isEmpty {
                return clean
            }
        }
        return "1.2.0"
    }

    static func normalizedVersion(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    static func versionComponents(_ raw: String) -> [Int]? {
        let normalized = normalizedVersion(raw)
        let core = normalized.split(maxSplits: 1, omittingEmptySubsequences: false) { $0 == "-" || $0 == "+" }.first ?? ""
        guard !core.isEmpty else { return nil }

        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        numbers.reserveCapacity(parts.count)
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let value = Int(part) else {
                return nil
            }
            numbers.append(value)
        }
        return numbers
    }

    static func isNewer(latest: String, than current: String) -> Bool {
        guard let latestParts = versionComponents(latest),
              let currentParts = versionComponents(current) else {
            return false
        }
        let maxCount = max(latestParts.count, currentParts.count)
        for idx in 0..<maxCount {
            let lhs = idx < latestParts.count ? latestParts[idx] : 0
            let rhs = idx < currentParts.count ? currentParts[idx] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }

    static func isTrustedGitHubURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "github.com"
    }

    static func parseSHA256Digest(_ raw: String?) -> String? {
        guard var trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasPrefix("sha256:") {
            trimmed.removeFirst("sha256:".count)
        }
        guard trimmed.count == 64,
              trimmed.unicodeScalars.allSatisfy({
                  ($0.value >= 48 && $0.value <= 57) || ($0.value >= 97 && $0.value <= 102)
              }) else {
            return nil
        }
        return trimmed
    }

    static func parseLatestRelease(from data: Data) -> ReleaseInfo? {
        guard let payload = try? JSONDecoder().decode(GitHubReleasePayload.self, from: data),
              payload.draft != true,
              payload.prerelease != true,
              versionComponents(payload.tagName) != nil,
              let releaseURL = URL(string: payload.htmlURL),
              isTrustedGitHubURL(releaseURL) else {
            return nil
        }

        let dmgAsset = (payload.assets ?? []).first { asset in
            asset.name.lowercased().hasSuffix(".dmg")
                && URL(string: asset.browserDownloadURL).map(isTrustedGitHubURL) == true
        }
        let dmgURL = dmgAsset.flatMap { URL(string: $0.browserDownloadURL) }
        let dmgSHA256 = dmgAsset.flatMap { parseSHA256Digest($0.digest) }

        return ReleaseInfo(
            version: normalizedVersion(payload.tagName),
            tagName: payload.tagName.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseURL: releaseURL,
            dmgURL: dmgURL,
            dmgSHA256: dmgSHA256
        )
    }

    static func sha256Hex(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 65_536)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func canSelfInstall(bundleURL: URL, isWritable: Bool) -> Bool {
        guard isWritable, bundleURL.pathExtension.lowercased() == "app" else {
            return false
        }
        let path = bundleURL.standardizedFileURL.path
        if path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/") {
            return false
        }
        return true
    }

    static func validateStagedAppBundle(
        at appURL: URL,
        expectedBundleID: String = "com.budimansusanto777.floqy"
    ) -> Bool {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String,
              bundleID == expectedBundleID,
              let executable = plist["CFBundleExecutable"] as? String,
              !executable.isEmpty else {
            return false
        }
        let execURL = appURL.appendingPathComponent("Contents/MacOS/\(executable)")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: execURL.path, isDirectory: &isDir), !isDir.boolValue else {
            return false
        }
        return FileManager.default.isExecutableFile(atPath: execURL.path)
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable, Codable {
    case toggleNotch
    case openBoard
    case quickNote
    case toggleFocus
    case cameraMirror

    var id: String { rawValue }

    var hotKeyID: UInt32 {
        switch self {
        case .toggleNotch: return 1
        case .openBoard: return 2
        case .quickNote: return 3
        case .toggleFocus: return 4
        case .cameraMirror: return 5
        }
    }

    var title: String {
        switch self {
        case .toggleNotch: return "Toggle Notch"
        case .openBoard: return "Copy History (Board)"
        case .quickNote: return "Quick Note"
        case .toggleFocus: return "Start / Pause Focus"
        case .cameraMirror: return "Camera Mirror"
        }
    }

    init?(hotKeyID: UInt32) {
        guard let match = Self.allCases.first(where: { $0.hotKeyID == hotKeyID }) else {
            return nil
        }
        self = match
    }
}

struct GlobalShortcut: Equatable, Codable {
    // Match Carbon.HIToolbox modifier masks (cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096)
    static let cmdMask: UInt32 = 256
    static let shiftMask: UInt32 = 512
    static let optionMask: UInt32 = 2048
    static let controlMask: UInt32 = 4096
    static let allowedModifierMask: UInt32 = cmdMask | shiftMask | optionMask | controlMask

    let keyCode: UInt32
    let carbonModifiers: UInt32

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers & Self.allowedModifierMask
    }

    var isValid: Bool {
        let hasPrimaryModifier = (carbonModifiers & (Self.cmdMask | Self.optionMask | Self.controlMask)) != 0
        return hasPrimaryModifier && ShortcutLogic.keyLabel(for: keyCode) != nil
    }

    var displayString: String {
        var parts: [String] = []
        if (carbonModifiers & Self.cmdMask) != 0 { parts.append("⌘") }
        if (carbonModifiers & Self.shiftMask) != 0 { parts.append("⇧") }
        if (carbonModifiers & Self.optionMask) != 0 { parts.append("⌥") }
        if (carbonModifiers & Self.controlMask) != 0 { parts.append("⌃") }
        parts.append(ShortcutLogic.keyLabel(for: keyCode) ?? "Key \(keyCode)")
        return parts.joined(separator: " ")
    }
}

/// Manages customizable global Carbon hotkey bindings, labels, and conflict checks.
enum ShortcutLogic {
    static let defaultBindings: [ShortcutAction: GlobalShortcut] = [
        .toggleNotch: GlobalShortcut(keyCode: 49, carbonModifiers: GlobalShortcut.cmdMask | GlobalShortcut.shiftMask),
        .openBoard: GlobalShortcut(keyCode: 9, carbonModifiers: GlobalShortcut.cmdMask | GlobalShortcut.shiftMask)
    ]

    static func conflictAction(
        for candidate: GlobalShortcut,
        excluding action: ShortcutAction,
        in bindings: [ShortcutAction: GlobalShortcut]
    ) -> ShortcutAction? {
        for other in ShortcutAction.allCases where other != action {
            if bindings[other] == candidate {
                return other
            }
        }
        return nil
    }

    static func keyLabel(for keyCode: UInt32) -> String? {
        keyLabels[keyCode]
    }

    private static let keyLabels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1"
    ]
}
