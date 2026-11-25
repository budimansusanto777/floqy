import AppKit
import Combine
import Foundation

/// Listens to Spotify & Apple Music playback notifications and controls active players via AppleScript.
@MainActor
final class MusicService: ObservableObject {
    @Published private(set) var track: NowPlayingTrack?
    @Published private(set) var artworkImage: NSImage?

    private static let spotifyBundleID = "com.spotify.client"
    private static let appleMusicBundleID = "com.apple.Music"

    private var observers: [NSObjectProtocol] = []
    private var playbackTimer: Timer?
    private var tickCount = 0
    private var cachedArtworkKey: String?

    func start() {
        stop()

        let center = DistributedNotificationCenter.default()
        observers.append(
            center.addObserver(
                forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshRunningPlayer(preferred: .spotify)
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: NSNotification.Name("com.apple.Music.playerInfo"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshRunningPlayer(preferred: .appleMusic)
                }
            }
        )

        Task { [weak self] in
            await self?.refreshRunningPlayer(preferred: nil)
        }
    }

    func stop() {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let source = activeSource() else { return }
        if var current = track {
            current.isPlaying.toggle()
            track = current
            syncPlaybackTimer()
        }
        let appName = appleScriptAppName(for: source)
        Task { [weak self] in
            _ = await Self.runAppleScript("tell application \"\(appName)\" to playpause")
            await self?.refreshRunningPlayer(preferred: source)
        }
    }

    func nextTrack() {
        guard let source = activeSource() else { return }
        let appName = appleScriptAppName(for: source)
        Task { [weak self] in
            _ = await Self.runAppleScript("tell application \"\(appName)\" to next track")
            try? await Task.sleep(for: .milliseconds(250))
            await self?.refreshRunningPlayer(preferred: source)
        }
    }

    func previousTrack() {
        guard let source = activeSource() else { return }
        let appName = appleScriptAppName(for: source)
        Task { [weak self] in
            _ = await Self.runAppleScript("tell application \"\(appName)\" to previous track")
            try? await Task.sleep(for: .milliseconds(250))
            await self?.refreshRunningPlayer(preferred: source)
        }
    }

    func seek(to fraction: Double) {
        guard var current = track, current.duration > 0 else { return }
        let clamped = min(1.0, max(0.0, fraction))
        let targetSeconds = current.duration * clamped
        current.position = targetSeconds
        track = current

        let appName = appleScriptAppName(for: current.source)
        let formattedSeconds = String(format: "%.2f", targetSeconds)
        Task { [weak self] in
            _ = await Self.runAppleScript("tell application \"\(appName)\" to set player position to \(formattedSeconds)")
            await self?.refreshRunningPlayer(preferred: current.source)
        }
    }

    // MARK: - Metadata Polling

    private func activeSource() -> MusicSource? {
        if let current = track?.source, isAppRunning(bundleID(for: current)) {
            return current
        }
        if isAppRunning(Self.spotifyBundleID) { return .spotify }
        if isAppRunning(Self.appleMusicBundleID) { return .appleMusic }
        return nil
    }

    private func refreshRunningPlayer(preferred: MusicSource?) async {
        let spotifyRunning = isAppRunning(Self.spotifyBundleID)
        let musicRunning = isAppRunning(Self.appleMusicBundleID)

        let candidates: [MusicSource]
        switch preferred {
        case .spotify:
            candidates = (spotifyRunning ? [.spotify] : []) + (musicRunning ? [.appleMusic] : [])
        case .appleMusic:
            candidates = (musicRunning ? [.appleMusic] : []) + (spotifyRunning ? [.spotify] : [])
        case nil:
            candidates = (spotifyRunning ? [.spotify] : []) + (musicRunning ? [.appleMusic] : [])
        }

        guard !candidates.isEmpty else {
            track = nil
            artworkImage = nil
            cachedArtworkKey = nil
            syncPlaybackTimer()
            return
        }

        for source in candidates {
            if let fetched = await fetchTrack(from: source) {
                track = fetched
                syncPlaybackTimer()
                await loadArtworkIfNeeded(for: fetched)
                return
            }
        }

        track = nil
        artworkImage = nil
        cachedArtworkKey = nil
        syncPlaybackTimer()
    }

    private func syncPlaybackTimer() {
        if track?.isPlaying == true {
            guard playbackTimer == nil else { return }
            tickCount = 0
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, var current = self.track, current.isPlaying else { return }
                    current.position = min(current.duration, current.position + 1.0)
                    self.track = current
                    self.tickCount += 1
                    if self.tickCount >= 10 {
                        self.tickCount = 0
                        await self.refreshRunningPlayer(preferred: current.source)
                    }
                }
            }
        } else {
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
    }

    private func fetchTrack(from source: MusicSource) async -> NowPlayingTrack? {
        let separator = "||FLOQY||"
        let script: String
        switch source {
        case .spotify:
            script = """
            tell application "Spotify"
                if player state is stopped then return ""
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDur to duration of current track
                set tPos to player position
                set tState to (player state as string)
                set tArt to artwork url of current track
                return tName & "\(separator)" & tArtist & "\(separator)" & tAlbum & "\(separator)" & tDur & "\(separator)" & tPos & "\(separator)" & tState & "\(separator)" & tArt
            end tell
            """
        case .appleMusic:
            script = """
            tell application "Music"
                if player state is stopped then return ""
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDur to duration of current track
                set tPos to player position
                set tState to (player state as string)
                return tName & "\(separator)" & tArtist & "\(separator)" & tAlbum & "\(separator)" & tDur & "\(separator)" & tPos & "\(separator)" & tState
            end tell
            """
        }

        guard let output = await Self.runAppleScript(script), !output.isEmpty else {
            return nil
        }
        let parts = output.components(separatedBy: separator)
        guard parts.count >= 6 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let rawDuration = parseAppleScriptNumber(parts[3])
        let durationSeconds = source == .spotify ? rawDuration / 1000.0 : rawDuration
        let positionSeconds = parseAppleScriptNumber(parts[4])
        let isPlaying = parts[5].lowercased().contains("playing")
        let artworkURL = parts.count >= 7 ? URL(string: parts[6].trimmingCharacters(in: .whitespacesAndNewlines)) : nil

        return NowPlayingTrack(
            title: title,
            artist: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            duration: max(0, durationSeconds),
            position: max(0, positionSeconds),
            isPlaying: isPlaying,
            artworkURL: artworkURL
        )
    }

    private func loadArtworkIfNeeded(for track: NowPlayingTrack) async {
        let key = "\(track.source.rawValue)::\(track.title)::\(track.artworkURL?.absoluteString ?? "")"
        guard key != cachedArtworkKey else { return }
        cachedArtworkKey = key

        if let url = track.artworkURL {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if cachedArtworkKey == key, let image = NSImage(data: data) {
                    artworkImage = image
                }
                return
            } catch {
                artworkImage = nil
                return
            }
        }

        if track.source == .appleMusic {
            let data = await Task.detached(priority: .utility) { () -> Data? in
                let script = NSAppleScript(source: """
                tell application "Music"
                    if (count of artworks of current track) > 0 then
                        return raw data of artwork 1 of current track
                    end if
                end tell
                """)
                var error: NSDictionary?
                let descriptor = script?.executeAndReturnError(&error)
                return descriptor?.data
            }.value
            if cachedArtworkKey == key, let data, let image = NSImage(data: data) {
                artworkImage = image
            } else if cachedArtworkKey == key {
                artworkImage = nil
            }
        } else {
            artworkImage = nil
        }
    }

    private func isAppRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func bundleID(for source: MusicSource) -> String {
        switch source {
        case .spotify: return Self.spotifyBundleID
        case .appleMusic: return Self.appleMusicBundleID
        }
    }

    private func appleScriptAppName(for source: MusicSource) -> String {
        switch source {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }

    private func parseAppleScriptNumber(_ raw: String) -> Double {
        Double(raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static func runAppleScript(_ source: String) async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        }.value
    }
}
