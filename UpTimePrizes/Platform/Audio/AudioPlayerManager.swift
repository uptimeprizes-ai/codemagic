import Foundation
import AVFoundation

// MARK: - Manifest types (shared with DatabaseSeeder)

struct ManifestRegion: Codable {
    let startMs: Int
    let endMs: Int
}

struct ManifestSongRegions: Codable {
    let stage1: ManifestRegion
    let stage2: ManifestRegion
    let stage3: ManifestRegion
}

struct ManifestSong: Codable {
    let id: String
    let title: String
    let filename: String
    let dayNumber: Int
    let regions: ManifestSongRegions
}

struct ManifestLibrary: Codable {
    let title: String
    let songs: [ManifestSong]
}

struct AudioManifest: Codable {
    let version: Int
    let libraries: [String: ManifestLibrary]
}

// MARK: - AudioPlayerManager

/// Manages AVAudioPlayer for three-stage alarm playback.
/// Stage 1 and Stage 2 loop within their defined regions.
/// Stage 3 plays once through, then signals completion.
@MainActor
class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Published state

    @Published var isPlaying: Bool = false
    @Published var currentStageLabel: String = "Stage 1"

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var loopTimer: Timer?
    private var currentRegion: ManifestRegion?
    private var isLooping: Bool = false
    private var onStage3Finished: (() -> Void)?
    private var manifest: AudioManifest?

    // MARK: - Init

    override init() {
        super.init()
        manifest = Self.loadManifest()
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AudioPlayerManager] Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Manifest

    static func loadManifest() -> AudioManifest? {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[AudioPlayerManager] manifest.json not found in bundle")
            return nil
        }
        do {
            return try JSONDecoder().decode(AudioManifest.self, from: data)
        } catch {
            print("[AudioPlayerManager] Failed to decode manifest: \(error)")
            return nil
        }
    }

    func song(for libraryId: String, dayNumber: Int) -> ManifestSong? {
        return manifest?.libraries[libraryId]?.songs.first { $0.dayNumber == dayNumber }
    }

    // MARK: - Playback control

    /// Play a specific stage region of a song file.
    /// - Parameters:
    ///   - filename: Audio filename without extension (e.g. "bright_side_swing")
    ///   - subdirectory: Bundle subdirectory (e.g. "demo")
    ///   - region: The time region to play (startMs / endMs)
    ///   - loop: Whether to loop within the region
    ///   - onFinished: Called when Stage 3 finishes playing (not called for looping stages)
    func playRegion(
        filename: String,
        subdirectory: String?,
        region: ManifestRegion,
        loop: Bool,
        onFinished: (() -> Void)? = nil
    ) {
        stopAll()

        guard let url = bundleURL(for: filename, subdirectory: subdirectory) else {
            print("[AudioPlayerManager] Audio file not found: \(filename)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()

            let startSec = Double(region.startMs) / 1000.0
            let endMs = region.endMs
            player?.currentTime = startSec

            if loop {
                isLooping = true
                currentRegion = region
                onStage3Finished = nil
                player?.play()
                scheduleLoopTimer(region: region)
            } else {
                // Stage 3: play once, stop at endMs if specified
                isLooping = false
                currentRegion = region
                onStage3Finished = onFinished
                player?.play()
                if endMs > 0 {
                    let duration = Double(endMs - region.startMs) / 1000.0
                    loopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            self?.handleStage3Finished()
                        }
                    }
                }
                // If endMs == -1, play to natural end; delegate fires audioPlayerDidFinishPlaying
            }

            isPlaying = true
        } catch {
            print("[AudioPlayerManager] Failed to create AVAudioPlayer: \(error)")
        }
    }

    /// Convenience: play Stage 1 (The Invite) — loops
    func playStage1(filename: String, subdirectory: String?, region: ManifestRegion) {
        currentStageLabel = "Stage 1 — The Invite"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: true)
    }

    /// Convenience: play Stage 2 (The Nudge) — loops
    func playStage2(filename: String, subdirectory: String?, region: ManifestRegion) {
        currentStageLabel = "Stage 2 — The Nudge"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: true)
    }

    /// Convenience: play Stage 3 (The Prize) — plays once
    func playStage3(filename: String, subdirectory: String?, region: ManifestRegion, onFinished: @escaping () -> Void) {
        currentStageLabel = "Stage 3 — The Prize"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: false, onFinished: onFinished)
    }

    /// Replay Stage 3 from the beginning of its region (one additional listen)
    func replay(filename: String, subdirectory: String?, region: ManifestRegion, onFinished: @escaping () -> Void) {
        currentStageLabel = "Replay"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: false, onFinished: onFinished)
    }

    func stopAll() {
        loopTimer?.invalidate()
        loopTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        isLooping = false
        currentRegion = nil
        onStage3Finished = nil
    }

    // MARK: - Loop timer

    private func scheduleLoopTimer(region: ManifestRegion) {
        loopTimer?.invalidate()
        let duration = Double(region.endMs - region.startMs) / 1000.0
        guard duration > 0 else { return }
        loopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.loopRegion()
            }
        }
    }

    private func loopRegion() {
        guard isLooping, let region = currentRegion, let player = player else { return }
        let startSec = Double(region.startMs) / 1000.0
        player.currentTime = startSec
        if !player.isPlaying { player.play() }
        scheduleLoopTimer(region: region)
    }

    private func handleStage3Finished() {
        isPlaying = false
        player?.stop()
        loopTimer?.invalidate()
        loopTimer = nil
        onStage3Finished?()
        onStage3Finished = nil
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // Only fires for Stage 3 with endMs == -1 (play to end of file)
            if !self.isLooping {
                self.handleStage3Finished()
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[AudioPlayerManager] Decode error: \(String(describing: error))")
    }

    // MARK: - Bundle URL helper

    private func bundleURL(for filename: String, subdirectory: String?) -> URL? {
        if let sub = subdirectory {
            return Bundle.main.url(forResource: filename, withExtension: "m4a", subdirectory: sub)
                ?? Bundle.main.url(forResource: filename, withExtension: "m4a")
        }
        return Bundle.main.url(forResource: filename, withExtension: "m4a")
    }
}
