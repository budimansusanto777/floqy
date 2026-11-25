import Foundation

enum TrayFileKind: String, Equatable {
    case image = "IMG"
    case pdf = "PDF"
    case video = "VID"
    case audio = "AUD"
    case code = "CODE"
    case document = "DOC"
    case other = "FILE"
}

struct StagedFileItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let byteSize: Int64
    let kind: TrayFileKind
    let extLabel: String

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        byteSize: Int64,
        kind: TrayFileKind? = nil,
        extLabel: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.byteSize = max(0, byteSize)
        let ext = url.pathExtension.lowercased()
        self.kind = kind ?? Self.classify(pathExtension: ext)
        self.extLabel = extLabel ?? (ext.isEmpty ? "FILE" : ext.uppercased())
    }

    var formattedSize: String {
        Self.formatByteCount(byteSize)
    }

    var supportsCompression: Bool {
        kind == .image || kind == .pdf
    }

    var supportsOCR: Bool {
        kind == .image || kind == .pdf
    }

    static func classify(pathExtension: String) -> TrayFileKind {
        let ext = pathExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "heif", "webp", "tiff", "tif", "gif", "bmp":
            return .image
        case "pdf":
            return .pdf
        case "mov", "mp4", "m4v", "mkv", "avi", "webm":
            return .video
        case "mp3", "m4a", "wav", "aac", "flac", "ogg":
            return .audio
        case "swift", "ts", "tsx", "js", "jsx", "py", "go", "rs", "json", "yaml", "yml", "sh", "html", "css", "sql":
            return .code
        case "md", "txt", "rtf", "doc", "docx", "pages", "csv":
            return .document
        default:
            return .other
        }
    }

    static func formatByteCount(_ bytes: Int64) -> String {
        let clamped = max(0, bytes)
        if clamped < 1024 {
            return "\(clamped) B"
        }
        let kb = Double(clamped) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.0f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024.0 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }
}

enum ObsidianNoteTarget: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case quickIdeas = "Quick Ideas"
    case inbox = "Inbox"

    var id: String { rawValue }
}

enum ObsidianLogic {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func resolveRelativePath(for target: ObsidianNoteTarget, date: Date = Date()) -> String {
        switch target {
        case .daily:
            return "Daily/\(dateFormatter.string(from: date)).md"
        case .quickIdeas:
            return "Inbox/Quick-Ideas.md"
        case .inbox:
            return "Inbox.md"
        }
    }

    static func formatMarkdownEntry(body: String, tags: [String], timestamp: Date = Date()) -> String {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeString = timeFormatter.string(from: timestamp)
        let existingLower = trimmedBody.lowercased()

        var appendedTags: [String] = []
        var seen: Set<String> = []
        for rawTag in tags {
            let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else { continue }
            let normalized = trimmedTag.hasPrefix("#") ? trimmedTag : "#\(trimmedTag)"
            let lower = normalized.lowercased()
            guard !seen.contains(lower), !existingLower.contains(lower) else { continue }
            seen.insert(lower)
            appendedTags.append(normalized)
        }

        let suffix = appendedTags.isEmpty ? "" : " " + appendedTags.joined(separator: " ")
        return "- \(timeString) \(trimmedBody)\(suffix)\n"
    }

    static func safeTargetURL(vaultURL: URL, relativePath: String) -> URL? {
        let standardizedVault = vaultURL.standardizedFileURL
        let candidate = standardizedVault.appendingPathComponent(relativePath).standardizedFileURL
        let vaultPath = standardizedVault.path.hasSuffix("/")
            ? standardizedVault.path
            : standardizedVault.path + "/"
        guard candidate.path.hasPrefix(vaultPath) else {
            return nil
        }
        return candidate
    }
}

enum ClipboardEntryKind: String, Equatable {
    case url = "URL"
    case code = "CODE"
    case image = "IMG"
    case text = "TEXT"
}

struct ClipboardEntry: Identifiable, Equatable {
    let id: UUID
    let kind: ClipboardEntryKind
    let textContent: String
    let imageData: Data?
    var isPinned: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ClipboardEntryKind,
        textContent: String,
        imageData: Data? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.textContent = textContent
        self.imageData = imageData
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}

enum ClipboardLogic {
    static func classifyText(_ raw: String) -> ClipboardEntryKind {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains(" "),
           let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return .url
        }

        let codeMarkers = [
            "func ", "struct ", "class ", "import ", "let ", "const ",
            "return ", "=>", "{", "}", "()", "-> ", "SELECT ", "FROM "
        ]
        if trimmed.contains("\n") || codeMarkers.contains(where: { trimmed.contains($0) }) {
            return .code
        }

        return .text
    }

    static func filterAndSort(_ entries: [ClipboardEntry], query: String) -> [ClipboardEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [ClipboardEntry]
        if q.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter { entry in
                entry.textContent.lowercased().contains(q)
                    || entry.kind.rawValue.lowercased().contains(q)
            }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
