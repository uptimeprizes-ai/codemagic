import Foundation
import AVFoundation

// Manifest types live in Data/Manifest/UpTimeManifest.swift (Android schema).

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
    private var manifest: UpTimeManifest?

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
            UpTimeLog.audio.error("[AUDIO] audio session activation failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Manifest

    static func loadManifest() -> UpTimeManifest? {
        UpTimeManifest.loadFromBundle()
    }

    /// The song for a journey's 1-based morning number, wrapping round after
    /// the last song (identity is journeyId; order is manifest sortOrder).
    func song(forJourneyId journeyId: String, morning: Int) -> ManifestSong? {
        manifest?.song(forJourneyId: journeyId, morning: morning)
    }

    /// Songs for a journey in manifest order (for the Player page).
    func songs(forJourneyId journeyId: String) -> [ManifestSong] {
        manifest?.songs(forJourneyId: journeyId) ?? []
    }

    // MARK: - Playback control

    /// Returns true only if playback actually started — the caller's proof
    /// that audio sounded. A missing file or player failure returns false,
    /// and a morning that never sounded must never count.
    @discardableResult
    func playRegion(
        filename: String,
        subdirectory: String?,
        region: ManifestRegion,
        loop: Bool,
        onFinished: (() -> Void)? = nil
    ) -> Bool {
        stopAll()

        // Re-activate audio session immediately before playback
        activateAlarmAudioSession()

        guard let url = bundleURL(for: filename, subdirectory: subdirectory) else {
            UpTimeLog.audio.error("[AUDIO] file not found: \(filename, privacy: .public)")
            return false
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
            UpTimeLog.audio.notice("[AUDIO] playing \(filename, privacy: .public) \(region.startMs, privacy: .public)–\(region.endMs, privacy: .public)ms loop=\(loop, privacy: .public)")
            return true
        } catch {
            UpTimeLog.audio.error("[AUDIO] player creation failed: \(error, privacy: .public)")
            return false
        }
    }

    @discardableResult
    func playStage1(filename: String, subdirectory: String?, region: ManifestRegion) -> Bool {
        currentStageLabel = "Stage 1 — The Invite"
        return playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: true)
    }

    @discardableResult
    func playStage2(filename: String, subdirectory: String?, region: ManifestRegion) -> Bool {
        currentStageLabel = "Stage 2 — The Nudge"
        return playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: true)
    }

    @discardableResult
    func playStage3(filename: String, subdirectory: String?, region: ManifestRegion, onFinished: @escaping () -> Void) -> Bool {
        currentStageLabel = "Stage 3 — The Prize"
        return playRegion(filename: filename, subdirectory: subdirectory, region: region, loop: false, onFinished: onFinished)
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
        UpTimeLog.audio.error("[AUDIO] decode error: \(String(describing: error), privacy: .public)")
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
            UpTimeLog.audio.error("[AUDIO] preview play error: \(error, privacy: .public)")
        }
    }
}
