import AppKit
import Combine
import Foundation

/// Lightweight NSPasteboard watcher storing recent text, code, URLs, and image thumbnails.
@MainActor
final class ClipboardService: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var searchQuery: String = ""

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let maxEntries = 40

    var filteredEntries: [ClipboardEntry] {
        ClipboardLogic.filterAndSort(entries, query: searchQuery)
    }

    var hasUnpinnedEntries: Bool {
        entries.contains { !$0.isPinned }
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copyToPasteboard(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if entry.kind == .image, let data = entry.imageData, let image = NSImage(data: data) {
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
        entries.removeAll { $0.id == id }
    }

    func clearUnpinned() {
        entries.removeAll { !$0.isPinned }
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let top = entries.first, top.kind != .image && top.textContent == text {
                return
            }

            let kind = ClipboardLogic.classifyText(text)
            insertEntry(ClipboardEntry(kind: kind, textContent: text))
            return
        }

        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData),
           let thumbData = downscaledPNGData(for: image, maxSide: 96) {
            let sizeLabel = "Image (\(Int(image.size.width)) × \(Int(image.size.height)))"
            insertEntry(ClipboardEntry(kind: .image, textContent: sizeLabel, imageData: thumbData))
        }
    }

    private func insertEntry(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        while entries.count > maxEntries {
            if let lastUnpinned = entries.lastIndex(where: { !$0.isPinned }) {
                entries.remove(at: lastUnpinned)
            } else {
                entries.removeLast()
            }
        }
    }

    private func downscaledPNGData(for image: NSImage, maxSide: CGFloat) -> Data? {
        let original = image.size
        guard original.width > 0, original.height > 0 else { return nil }
        let ratio = min(1.0, maxSide / max(original.width, original.height))
        let targetSize = NSSize(width: max(1, round(original.width * ratio)), height: max(1, round(original.height * ratio)))

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: original), operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
