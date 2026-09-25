import Foundation
import AVFoundation

// MARK: - LibraryPlayer
//
// The Player tab's playback (Android PlayerPageViewModel): plays the Prize
// region of an owned song, with pause, seek and position. Kept apart from
// AudioPlayerManager so nothing here can disturb an alarm; the alarm stops
// this player whenever it starts sounding.

@MainActor
final class LibraryPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {

    static let shared = LibraryPlayer()

    struct Track: Equatable {
        let songId: String
        let title: String
        let fileStem: String
        let subdirectory: String
        let startMs: Int
        let endMs: Int
    }

    @Published private(set) var current: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var positionMs = 0
    /// The song's audio has not arrived on this device (curator: NOT READY YET).
    @Published private(set) var notReady = false

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    var durationMs: Int {
        guard let current else { return 1 }
        return max(1, current.endMs - current.startMs)
    }

    func play(_ track: Track) {
        stop()
        current = track
        guard let url = Bundle.main.url(forResource: track.fileStem, withExtension: "m4a", subdirectory: track.subdirectory)
            ?? Bundle.main.url(forResource: track.fileStem, withExtension: "m4a") else {
            notReady = true
            UpTimeLog.audio.notice("[AUDIO] player: \(track.fileStem, privacy: .public) not on this device yet")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.currentTime = Double(track.startMs) / 1000
            newPlayer.play()
            player = newPlayer
            isPlaying = true
            startTicker()
            UpTimeLog.audio.notice("[AUDIO] player: playing \(track.fileStem, privacy: .public)")
        } catch {
            notReady = true
            UpTimeLog.audio.error("[AUDIO] player: could not open \(track.fileStem, privacy: .public): \(error, privacy: .public)")
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTicker()
        } else {
            player.play()
            isPlaying = true
            startTicker()
        }
    }

    func seek(toMs ms: Int) {
        guard let player, let current else { return }
        let clamped = min(max(ms, 0), durationMs)
        player.currentTime = Double(current.startMs + clamped) / 1000
        positionMs = clamped
    }

    func stop() {
        stopTicker()
        player?.stop()
        player = nil
        current = nil
        isPlaying = false
        positionMs = 0
        notReady = false
    }

    // MARK: - Progress

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let player, let current else { return }
        let position = Int(player.currentTime * 1000) - current.startMs
        if position >= durationMs {
            finish()
        } else {
            positionMs = max(0, position)
        }
    }

    /// The song reached the end of its Prize region: rewind and wait.
    private func finish() {
        guard let current else { return }
        player?.pause()
        player?.currentTime = Double(current.startMs) / 1000
        isPlaying = false
        positionMs = 0
        stopTicker()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finish()
        }
    }
}
