import AppKit
import Combine
import Foundation
import ImageIO

/// Lightweight NSPasteboard watcher storing recent text, code, URLs, and image thumbnails.
@MainActor
final class ClipboardService: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var searchQuery: String = ""

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var isDisplayAsleep = false
    private let maxEntries = 40

    private static var clipboardTempDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("FloqyClipboard", isDirectory: true)
    }

    init() {
        try? FileManager.default.removeItem(at: Self.clipboardTempDir)
    }

    var filteredEntries: [ClipboardEntry] {
        ClipboardLogic.filterAndSort(entries, query: searchQuery)
    }

    var hasUnpinnedEntries: Bool {
        entries.contains { !$0.isPinned }
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        if !isDisplayAsleep {
            startPollingTimer()
        }
    }

    func setDisplayAsleep(_ asleep: Bool) {
        guard isDisplayAsleep != asleep else { return }
        isDisplayAsleep = asleep
        if asleep {
            timer?.invalidate()
            timer = nil
        } else {
            pruneExpiredEntries()
            lastChangeCount = NSPasteboard.general.changeCount
            startPollingTimer()
        }
    }

    private func startPollingTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for entry in entries {
            cleanupTempFile(entry.fullImageURL)
        }
        try? FileManager.default.removeItem(at: Self.clipboardTempDir)
    }

    func copyToPasteboard(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if entry.kind == .image,
           let data = entry.fullImageURL.flatMap({ try? Data(contentsOf: $0) }) ?? entry.imageData,
           let image = NSImage(data: data) {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.setString(entry.textContent, forType: .string)
        }
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isPinned.toggle()
    }

    func delete(_ id: UUID) {
        for entry in entries where entry.id == id {
            cleanupTempFile(entry.fullImageURL)
        }
        entries.removeAll { $0.id == id }
    }

    func clearUnpinned() {
        for entry in entries where !entry.isPinned {
            cleanupTempFile(entry.fullImageURL)
        }
        entries.removeAll { !$0.isPinned }
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let types = (pasteboard.types ?? []).map(\.rawValue)
        if ClipboardLogic.shouldIgnorePasteboardTypes(types) {
            return
        }

        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, ClipboardLogic.isTextWithinRetentionLimit(text) else { return }
            if let top = entries.first, top.kind != .image && top.textContent == text {
                return
            }

            let kind = ClipboardLogic.classifyText(text)
            insertEntry(ClipboardEntry(kind: kind, textContent: text))
            return
        }

        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let thumb = downscaledPNGAndSize(from: imageData, maxPixelSize: 96) {
            // Spill full-res image bytes to /tmp so RAM only holds the 96px thumbnail.
            let fullData = imageData.count <= 10_000_000
                ? imageData
                : downscaledPNGAndSize(from: imageData, maxPixelSize: 1600)?.pngData
            let entryID = UUID()
            let fullURL = fullData.flatMap { writeTempImage($0, id: entryID) }
            let sizeLabel = "Image (\(thumb.pixelWidth) × \(thumb.pixelHeight))"
            insertEntry(ClipboardEntry(id: entryID, kind: .image, textContent: sizeLabel, imageData: thumb.pngData, fullImageURL: fullURL))
        }
    }

    private func insertEntry(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        pruneExpiredEntries()
        while entries.filter({ $0.kind == .image }).count > 5 {
            if let oldestUnpinnedImage = entries.lastIndex(where: { $0.kind == .image && !$0.isPinned }) {
                cleanupTempFile(entries[oldestUnpinnedImage].fullImageURL)
                entries.remove(at: oldestUnpinnedImage)
            } else {
                break
            }
        }
        while entries.count > maxEntries {
            if let lastUnpinned = entries.lastIndex(where: { !$0.isPinned }) {
                cleanupTempFile(entries[lastUnpinned].fullImageURL)
                entries.remove(at: lastUnpinned)
            } else {
                cleanupTempFile(entries.last?.fullImageURL)
                entries.removeLast()
            }
        }
    }

    private func pruneExpiredEntries(now: Date = Date()) {
        let expiredIDs = ClipboardLogic.expiredUnpinnedIDs(in: entries, now: now)
        guard !expiredIDs.isEmpty else { return }
        for entry in entries where expiredIDs.contains(entry.id) {
            cleanupTempFile(entry.fullImageURL)
        }
        entries.removeAll { expiredIDs.contains($0.id) }
    }

    private func writeTempImage(_ data: Data, id: UUID) -> URL? {
        let dir = Self.clipboardTempDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id.uuidString).img")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func cleanupTempFile(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func downscaledPNGAndSize(from data: Data, maxPixelSize: Int) -> (pngData: Data, pixelWidth: Int, pixelHeight: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelW = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let pixelH = props?[kCGImagePropertyPixelHeight] as? Int ?? 0

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgThumb)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return nil }
        return (pngData, max(pixelW, cgThumb.width), max(pixelH, cgThumb.height))
    }
}
