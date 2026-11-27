import Foundation

enum UpdateInstallError: LocalizedError {
    case missingDMGAsset
    case untrustedDownloadURL
    case missingChecksum
    case checksumMismatch
    case downloadFailed(String)
    case mountFailed
    case invalidAppBundle
    case notWritableTarget
    case launchFailed

    var errorDescription: String? {
        switch self {
        case .missingDMGAsset:
            return "No DMG asset found on this release."
        case .untrustedDownloadURL:
            return "Download URL is not a trusted GitHub link."
        case .missingChecksum:
            return "Release checksum missing. Download the DMG manually instead."
        case .checksumMismatch:
            return "Downloaded DMG failed SHA-256 verification."
        case .downloadFailed(let detail):
            return "Download failed: \(detail)"
        case .mountFailed:
            return "Could not mount the downloaded DMG."
        case .invalidAppBundle:
            return "Downloaded update bundle failed validation."
        case .notWritableTarget:
            return "Move Floqy to Applications before auto-updating."
        case .launchFailed:
            return "Could not start the update installer."
        }
    }
}

/// Downloads, SHA-256 verifies, mounts, stages, and atomically replaces the running Floqy bundle.
enum UpdateInstaller {
    static func canSelfInstallCurrentApp() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        let fm = FileManager.default
        let isWritable = fm.isWritableFile(atPath: bundleURL.path)
            && fm.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
        return UpdateLogic.canSelfInstall(bundleURL: bundleURL, isWritable: isWritable)
    }

    static func downloadAndStage(
        release: ReleaseInfo,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard let dmgURL = release.dmgURL else {
            throw UpdateInstallError.missingDMGAsset
        }
        guard UpdateLogic.isTrustedGitHubURL(dmgURL) else {
            throw UpdateInstallError.untrustedDownloadURL
        }
        guard let expectedSHA = release.dmgSHA256 else {
            throw UpdateInstallError.missingChecksum
        }

        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("FloqyUpdate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

        var keepWorkDir = false
        defer {
            if !keepWorkDir {
                try? fm.removeItem(at: workDir)
            }
        }

        let localDMGURL = workDir.appendingPathComponent("Floqy.dmg")
        try await downloadFile(from: dmgURL, to: localDMGURL, onProgress: onProgress)

        let actualSHA = try await Task.detached(priority: .userInitiated) {
            try UpdateLogic.sha256Hex(of: localDMGURL)
        }.value
        guard actualSHA == expectedSHA else {
            throw UpdateInstallError.checksumMismatch
        }

        let mountPoint = workDir.appendingPathComponent("mnt", isDirectory: true)
        try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let stagedAppURL = workDir.appendingPathComponent("Floqy.app", isDirectory: true)
        try await Task.detached(priority: .userInitiated) {
            guard runTool("/usr/bin/hdiutil", arguments: [
                "attach", localDMGURL.path,
                "-nobrowse", "-readonly", "-noverify",
                "-mountpoint", mountPoint.path
            ]) == 0 else {
                throw UpdateInstallError.mountFailed
            }
            defer {
                _ = runTool("/usr/bin/hdiutil", arguments: ["detach", mountPoint.path, "-force"])
            }

            let sourceAppURL = try locateAppBundle(in: mountPoint)
            guard runTool("/usr/bin/ditto", arguments: [sourceAppURL.path, stagedAppURL.path]) == 0 else {
                throw UpdateInstallError.invalidAppBundle
            }
        }.value

        guard UpdateLogic.validateStagedAppBundle(at: stagedAppURL) else {
            throw UpdateInstallError.invalidAppBundle
        }

        try? fm.removeItem(at: localDMGURL)
        try? fm.removeItem(at: mountPoint)
        keepWorkDir = true
        return stagedAppURL
    }

    static func replaceAndRelaunch(stagedAppURL: URL, targetAppURL: URL) throws {
        let fm = FileManager.default
        let isWritable = fm.isWritableFile(atPath: targetAppURL.path)
            && fm.isWritableFile(atPath: targetAppURL.deletingLastPathComponent().path)
        guard UpdateLogic.canSelfInstall(bundleURL: targetAppURL, isWritable: isWritable) else {
            throw UpdateInstallError.notWritableTarget
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let workDir = stagedAppURL.deletingLastPathComponent()

        let script = """
        pid="$1"
        staged="$2"
        target="$3"
        workdir="$4"
        i=0
        while [ "$i" -lt 30 ]; do
          kill -0 "$pid" 2>/dev/null || break
          sleep 0.1
          i=$((i + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
          kill -TERM "$pid" 2>/dev/null || true
          j=0
          while [ "$j" -lt 10 ]; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
            j=$((j + 1))
          done
          kill -KILL "$pid" 2>/dev/null || true
        fi
        backup="${target}.floqy-backup.$$"
        rm -rf "$backup"
        if ! mv "$target" "$backup"; then
          rm -rf "$workdir"
          exit 1
        fi
        if mv "$staged" "$target"; then
          rm -rf "$backup" "$workdir"
          exec open -n "$target"
        else
          mv "$backup" "$target" 2>/dev/null || true
          rm -rf "$workdir"
          exit 1
        fi
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "_", "\(pid)", stagedAppURL.path, targetAppURL.path, workDir.path]
        process.standardInput = nil
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
        } catch {
            throw UpdateInstallError.launchFailed
        }
    }

    private static func locateAppBundle(in mountPoint: URL) throws -> URL {
        let preferred = mountPoint.appendingPathComponent("Floqy.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: preferred.path) {
            return preferred
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: mountPoint,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        if let app = entries.first(where: { $0.pathExtension.lowercased() == "app" }) {
            return app
        }
        throw UpdateInstallError.invalidAppBundle
    }

    private static func runTool(_ path: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardInput = nil
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private static func downloadFile(
        from url: URL,
        to destinationURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.setValue("Floqy/\(UpdateLogic.currentAppVersion())", forHTTPHeaderField: "User-Agent")

        let delegate = DMGDownloadDelegate(destinationURL: destinationURL, onProgress: onProgress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.start(with: session, request: request, continuation: continuation)
            }
        } onCancel: {
            delegate.cancel()
        }
    }
}

private final class DMGDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var task: URLSessionDownloadTask?
    private weak var session: URLSession?
    private var finished = false

    init(destinationURL: URL, onProgress: @escaping @Sendable (Double) -> Void) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
    }

    func start(
        with session: URLSession,
        request: URLRequest,
        continuation: CheckedContinuation<Void, Error>
    ) {
        lock.lock()
        self.session = session
        self.continuation = continuation
        let downloadTask = session.downloadTask(with: request)
        self.task = downloadTask
        lock.unlock()
        downloadTask.resume()
    }

    func cancel() {
        lock.lock()
        let activeTask = task
        let activeSession = session
        lock.unlock()
        activeTask?.cancel()
        activeSession?.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1.0, max(0.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        onProgress(fraction)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            complete(with: .failure(UpdateInstallError.downloadFailed("HTTP \(http.statusCode)")), session: session)
            return
        }

        do {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)
            onProgress(1.0)
            complete(with: .success(()), session: session)
        } catch {
            complete(with: .failure(UpdateInstallError.downloadFailed(error.localizedDescription)), session: session)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            complete(with: .failure(CancellationError()), session: session)
        } else {
            complete(with: .failure(UpdateInstallError.downloadFailed(error.localizedDescription)), session: session)
        }
    }

    private func complete(with result: Result<Void, Error>, session: URLSession) {
        lock.lock()
        guard !finished, let cont = continuation else {
            lock.unlock()
            return
        }
        finished = true
        continuation = nil
        task = nil
        lock.unlock()

        session.finishTasksAndInvalidate()
        cont.resume(with: result)
    }
}
