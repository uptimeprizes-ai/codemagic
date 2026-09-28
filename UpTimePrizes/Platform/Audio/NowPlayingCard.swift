import Foundation
import MediaPlayer

// MARK: - NowPlayingCard
//
// The lock-screen "Now Playing" card during a morning (founder, 2026-09-28).
// iOS refuses to pull the app onto a locked screen (build 137: RequestDenied),
// but tapping this card opens UpTime after Touch ID — Apple's own route from
// a locked phone to the app that is playing. It shows the song's title,
// "UpTime Prizes", and the stage; play and pause work from the lock screen.
//
// Words on the card are the song's manifest title, the app's name and the
// stage names — nothing new.

@MainActor
enum NowPlayingCard {

    /// Shows (or refreshes) the card. Looping stages carry no duration, so
    /// the lock screen shows no progress bar that would restart each loop.
    static func show(title: String, stage: String, duration: TimeInterval?, elapsed: TimeInterval, playing: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "UpTime Prizes",
            MPMediaItemPropertyAlbumTitle: stage,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed
        ]
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
    }

    /// Keeps the card's position and play/pause state honest after a pause.
    static func update(elapsed: TimeInterval, playing: Bool) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
    }

    static func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    /// Lock-screen play and pause. Skipping and scrubbing are off: a morning
    /// moves forward through its stages, not by a skip button.
    static func registerCommands(play: @escaping @MainActor () -> Void, pause: @escaping @MainActor () -> Void) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false

        center.playCommand.addTarget { _ in
            Task { @MainActor in play() }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            Task { @MainActor in pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                if MPNowPlayingInfoCenter.default().playbackState == .playing { pause() } else { play() }
            }
            return .success
        }
    }
}
