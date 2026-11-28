@preconcurrency import AVFoundation
import AppKit
import Combine
import SwiftUI

/// Drives an on-demand local AVCaptureSession preview for Quick Camera Mirror before joining meetings.
@MainActor
final class CameraMirrorService: ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var isMirrored: Bool = true
    @Published private(set) var session: AVCaptureSession?

    private let sessionQueue = DispatchQueue(label: "floqy.camera.mirror")

    func start() {
        errorMessage = nil
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status

        switch status {
        case .authorized:
            startSessionOnQueue()
        case .notDetermined:
            Task { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard let self else { return }
                self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                if granted {
                    self.startSessionOnQueue()
                } else {
                    self.errorMessage = "Camera access is disabled in System Settings."
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access is disabled in System Settings."
        @unknown default:
            errorMessage = "Camera unavailable."
        }
    }

    func stop() {
        isRunning = false
        guard let captureSession = session else { return }
        session = nil
        sessionQueue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
        }
    }

    func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startSessionOnQueue() {
        let captureSession = session ?? AVCaptureSession()
        if session == nil {
            session = captureSession
        }
        sessionQueue.async { [weak self] in
            guard let device = AVCaptureDevice.default(for: .video) else {
                Task { @MainActor [weak self] in
                    self?.isRunning = false
                    self?.session = nil
                    self?.errorMessage = "No camera detected."
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                captureSession.beginConfiguration()
                for existing in captureSession.inputs {
                    captureSession.removeInput(existing)
                }
                if captureSession.canSetSessionPreset(.vga640x480) {
                    captureSession.sessionPreset = .vga640x480
                } else if captureSession.canSetSessionPreset(.medium) {
                    captureSession.sessionPreset = .medium
                }
                guard captureSession.canAddInput(input) else {
                    captureSession.commitConfiguration()
                    Task { @MainActor [weak self] in
                        self?.isRunning = false
                        self?.session = nil
                        self?.errorMessage = "Could not attach camera input."
                    }
                    return
                }
                captureSession.addInput(input)
                captureSession.commitConfiguration()

                if !captureSession.isRunning {
                    captureSession.startRunning()
                }

                Task { @MainActor [weak self] in
                    guard let self, self.session === captureSession else {
                        self?.sessionQueue.async {
                            if captureSession.isRunning {
                                captureSession.stopRunning()
                            }
                            for existing in captureSession.inputs {
                                captureSession.removeInput(existing)
                            }
                        }
                        return
                    }
                    self.isRunning = true
                    self.errorMessage = nil
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.isRunning = false
                    self?.session = nil
                    self?.errorMessage = "Camera unavailable: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Hosts an AVCaptureVideoPreviewLayer with live mirror toggling.
struct CameraPreviewLayerView: NSViewRepresentable {
    let session: AVCaptureSession?
    let isMirrored: Bool
    let isRunning: Bool

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.attachSession(session)
        view.applyMirror(isMirrored)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.attachSession(session)
        nsView.applyMirror(isMirrored)
    }

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.attachSession(nil)
    }
}

final class CameraPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    private var desiredMirrored: Bool = true
    nonisolated(unsafe) private var startObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let startObserver {
            NotificationCenter.default.removeObserver(startObserver)
        }
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        applyMirror(desiredMirrored)
    }

    func attachSession(_ session: AVCaptureSession?) {
        guard previewLayer.session !== session else { return }
        if let startObserver {
            NotificationCenter.default.removeObserver(startObserver)
            self.startObserver = nil
        }
        previewLayer.session = session
        guard let session else { return }
        startObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.didStartRunningNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyMirror(self.desiredMirrored)
            }
        }
    }

    func applyMirror(_ mirrored: Bool) {
        desiredMirrored = mirrored
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else {
            return
        }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }
}
