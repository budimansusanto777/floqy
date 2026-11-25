import AppKit
import Combine
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

enum FilesTrayError: LocalizedError {
    case unsupportedFormat
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "File format does not support this action."
        case .processingFailed(let message):
            return message
        }
    }
}

/// Manages staged files in the Files Smart Tray along with AirDrop, compression, and offline OCR.
@MainActor
final class FilesTrayService: ObservableObject {
    @Published private(set) var items: [StagedFileItem] = []
    @Published var selectedID: UUID?
    @Published private(set) var isProcessing: Bool = false

    var selectedItem: StagedFileItem? {
        if let selectedID, let match = items.first(where: { $0.id == selectedID }) {
            return match
        }
        return items.first
    }

    func stageFiles(_ urls: [URL]) {
        var addedID: UUID?
        for url in urls {
            let standardized = url.standardizedFileURL
            if let existing = items.first(where: { $0.url.standardizedFileURL == standardized }) {
                addedID = existing.id
                continue
            }

            let values = try? standardized.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(values?.fileSize ?? 0)
            let item = StagedFileItem(url: standardized, byteSize: size)
            items.insert(item, at: 0)
            addedID = item.id
        }

        if items.count > 12 {
            items = Array(items.prefix(12))
        }
        if let addedID {
            selectedID = addedID
        }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = items.first?.id
        }
    }

    func clearAll() {
        items.removeAll()
        selectedID = nil
    }

    func pickFilesFromPanel() -> Int {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Add Files to Floqy Tray"
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return 0 }
        stageFiles(panel.urls)
        return panel.urls.count
    }

    // MARK: - Smart Actions

    func shareViaAirDrop(_ item: StagedFileItem) -> String {
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            return "AirDrop unavailable"
        }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: [item.url])
        return "Opening AirDrop for \(item.name)"
    }

    func compress(_ item: StagedFileItem) async -> String {
        guard item.supportsCompression else {
            return "Only images and PDFs can be compressed"
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let outputURL = try await Task.detached(priority: .userInitiated) {
                switch item.kind {
                case .image:
                    return try Self.compressImage(at: item.url)
                case .pdf:
                    return try Self.compressPDF(at: item.url)
                default:
                    throw FilesTrayError.unsupportedFormat
                }
            }.value

            let outSize = Int64((try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if item.byteSize > 0 && outSize >= item.byteSize {
                try? FileManager.default.removeItem(at: outputURL)
                return "\(item.name) is already optimal"
            }

            stageFiles([outputURL])
            if item.byteSize > 0 {
                let pct = max(1, Int(((Double(item.byteSize - outSize) / Double(item.byteSize)) * 100).rounded()))
                return "Compressed \(outputURL.lastPathComponent) (-\(pct)%)"
            }
            return "Compressed \(outputURL.lastPathComponent)"
        } catch {
            return error.localizedDescription
        }
    }

    func extractOCRText(_ item: StagedFileItem) async -> Result<String, Error> {
        guard item.supportsOCR else {
            return .failure(FilesTrayError.unsupportedFormat)
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let recognized = try await Task.detached(priority: .userInitiated) {
                switch item.kind {
                case .image:
                    return try Self.recognizeTextInImage(at: item.url)
                case .pdf:
                    return try Self.recognizeTextInPDF(at: item.url)
                default:
                    throw FilesTrayError.unsupportedFormat
                }
            }.value

            let trimmed = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .failure(FilesTrayError.processingFailed("No readable text found"))
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(trimmed, forType: .string)
            return .success(trimmed)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Off-Main ImageIO / PDFKit / Vision Workers

    private nonisolated static func trayOutputDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FloqyTray", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private nonisolated static func compressImage(at sourceURL: URL) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FilesTrayError.processingFailed("Could not decode image")
        }

        let supportedTypes = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        let webpType = "org.webmproject.webp"
        let useWebP = supportedTypes.contains(webpType)
        let targetType = useWebP ? webpType : UTType.jpeg.identifier
        let ext = useWebP ? "webp" : "jpg"

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outURL = try trayOutputDirectory().appendingPathComponent("\(baseName)-compressed.\(ext)")
        try? FileManager.default.removeItem(at: outURL)

        guard let destination = CGImageDestinationCreateWithURL(outURL as CFURL, targetType as CFString, 1, nil) else {
            throw FilesTrayError.processingFailed("Could not create compressed image")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.72
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw FilesTrayError.processingFailed("Image compression failed")
        }
        return outURL
    }

    private nonisolated static func compressPDF(at sourceURL: URL) throws -> URL {
        guard let doc = PDFDocument(url: sourceURL), doc.pageCount > 0 else {
            throw FilesTrayError.processingFailed("Could not open PDF")
        }

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outURL = try trayOutputDirectory().appendingPathComponent("\(baseName)-compressed.pdf")
        try? FileManager.default.removeItem(at: outURL)

        var firstBox = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdfContext = CGContext(outURL as CFURL, mediaBox: &firstBox, nil) else {
            throw FilesTrayError.processingFailed("Could not create output PDF")
        }

        let scale: CGFloat = 150.0 / 72.0
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let pageBox = page.bounds(for: .mediaBox)
            let pixelWidth = max(1, Int(pageBox.width * scale))
            let pixelHeight = max(1, Int(pageBox.height * scale))

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let bitmapCtx = CGContext(
                    data: nil,
                    width: pixelWidth,
                    height: pixelHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                continue
            }

            bitmapCtx.setFillColor(NSColor.white.cgColor)
            bitmapCtx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            bitmapCtx.saveGState()
            bitmapCtx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: bitmapCtx)
            bitmapCtx.restoreGState()

            guard let rendered = bitmapCtx.makeImage() else { continue }
            let rep = NSBitmapImageRep(cgImage: rendered)
            guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.68]),
                  let provider = CGDataProvider(data: jpegData as CFData),
                  let jpegImage = CGImage(
                    jpegDataProviderSource: provider,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent
                  ) else {
                continue
            }

            pdfContext.beginPDFPage([kCGPDFContextMediaBox as String: pageBox] as CFDictionary)
            pdfContext.draw(jpegImage, in: CGRect(origin: .zero, size: pageBox.size))
            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()
        return outURL
    }

    private nonisolated static func recognizeTextInImage(at url: URL) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(url: url, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private nonisolated static func recognizeTextInPDF(at url: URL) throws -> String {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw FilesTrayError.processingFailed("Could not open PDF")
        }

        let pageLimit = min(5, doc.pageCount)
        var pageTexts: [String] = []

        for index in 0..<pageLimit {
            guard let page = doc.page(at: index) else { continue }
            let thumbnail = page.thumbnail(of: CGSize(width: 1600, height: 2200), for: .mediaBox)
            guard let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            if !text.isEmpty {
                pageTexts.append(text)
            }
        }

        return pageTexts.joined(separator: "\n\n")
    }
}
