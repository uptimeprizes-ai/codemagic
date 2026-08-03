import Foundation
import AVFoundation

// MARK: - Manifest types

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
///
/// Audio session fix: Uses .playback category with NO mixing options so the
/// audio overrides the iPhone silent switch. The session is re-activated
/// immediately before each playback call to ensure it is active.
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
        // Configure audio session at init — will be re-activated before playback
        activateAlarmAudioSession()
    }

    // MARK: - Audio Session

    /// Configures and activates the AVAudioSession for alarm playback.
    /// .playback category without .mixWithOthers overrides the silent switch.
    /// Called at init AND immediately before every playback start.
    private func activateAlarmAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback without mixWithOthers = overrides silent switch
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioPlayerManager] Failed to activate AVAudioSession: \(error)")
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

    func playRegion(
        filename: String,
        subdirectory: String?,
        region: ManifestRegion,
        loop: Bool,
        onFinished: (() -> Void)? = nil
    ) {
        stopAll()

        // Re-activate audio session immediately before playback
        activateAlarmAudioSession()

        guard let url = bundleURL(for: filename, subdirectory: subdirectory) else {
            print("[AudioPlayerManager] Audio file not found: \(filename)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.volume = 1.0

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
            }

            isPlaying = true
        } catch {
            print("[AudioPlayerManager] Failed to create AVAudioPlayer: \(error)")
        }
    }

    func playStage1(filename: String, subdirectory: String?, region: ManifestRegion) {
        currentStageLabel = "Stage 1 — The Invite"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: true)
    }

    func playStage2(filename: String, subdirectory: String?, region: ManifestRegion) {
        currentStageLabel = "Stage 2 — The Nudge"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: true)
    }

    func playStage3(filename: String, subdirectory: String?, region: ManifestRegion, onFinished: @escaping () -> Void) {
        currentStageLabel = "Stage 3 — The Prize"
        playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: false, onFinished: onFinished)
    }

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

    // MARK: - Convenience play (for Player page preview)

    func play(filename: String, subdirectory: String?) {
        activateAlarmAudioSession()
        let url: URL?
        if let sub = subdirectory {
            url = Bundle.main.url(forResource: filename, withExtension: "m4a", subdirectory: sub)
                ?? Bundle.main.url(forResource: filename, withExtension: "m4a")
        } else {
            url = Bundle.main.url(forResource: filename, withExtension: "m4a")
        }
        guard let url = url else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 1.0
            p.play()
        } catch {
            print("[AudioPlayerManager] play(filename:subdirectory:) error: \(error)")
        }
    }
}
