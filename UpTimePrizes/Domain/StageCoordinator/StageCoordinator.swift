import Foundation
import Combine

// MARK: - StageCoordinator

/// Orchestrates the three-stage alarm experience.
/// Drives AudioPlayerManager through Stage 1 → Stage 2 → Stage 3 → Replay.
/// Stage 1 and Stage 2 loop; Stage 3 plays once, then exposes a Replay option.
@MainActor
class StageCoordinator: ObservableObject {

    // MARK: - Stage enum

    enum Stage: CaseIterable, Equatable {
        case stage1 // The Invite — loops
        case stage2 // The Nudge — loops
        case stage3 // The Prize — plays once
        case replay // One additional listen

        var index: Int {
            switch self {
            case .stage1: return 0
            case .stage2: return 1
            case .stage3: return 2
            case .replay: return 3
            }
        }
    }

    // MARK: - Published state

    @Published var currentStage: Stage = .stage1
    @Published var currentSong: ManifestSong?

    // MARK: - Private

    private var audioManager: AudioPlayerManager?
    private var currentFilename: String = ""
    private var currentSubdirectory: String?
    private var currentRegions: ManifestSongRegions?

    // MARK: - Computed

    var stageName: String {
        switch currentStage {
        case .stage1: return "The Invite"
        case .stage2: return "The Nudge"
        case .stage3: return "The Prize"
        case .replay: return "Replay"
        }
    }

    var stageIndex: Int { currentStage.index }

    // MARK: - Start alarm

    /// Begin the alarm experience for a given song.
    func startAlarm(
        song: ManifestSong,
        subdirectory: String?,
        audioManager: AudioPlayerManager
    ) {
        self.audioManager = audioManager
        self.currentSong = song
        self.currentFilename = song.filename
        self.currentSubdirectory = subdirectory
        self.currentRegions = song.regions
        currentStage = .stage1
        playCurrentStage()
    }

    // MARK: - Stage advancement

    /// Advance to the next stage (user-initiated or auto-advance from Stage 3 end).
    func advanceStage() {
        switch currentStage {
        case .stage1:
            currentStage = .stage2
            playCurrentStage()
        case .stage2:
            currentStage = .stage3
            playCurrentStage()
        case .stage3:
            // Stage 3 auto-advances to replay when finished
            currentStage = .replay
            audioManager?.stopAll()
        case .replay:
            break
        }
    }

    /// Handle the Replay button tap — replay Stage 3 once more.
    func handleReplay() {
        guard let regions = currentRegions, let audio = audioManager else { return }
        currentStage = .stage3
        audio.replay(
            filename: currentFilename,
            subdirectory: currentSubdirectory,
            region: regions.stage3
        ) { [weak self] in
            Task { @MainActor in
                self?.currentStage = .replay
            }
        }
    }

    // MARK: - Stop

    func stopAlarm() {
        audioManager?.stopAll()
        currentStage = .stage1
        currentSong = nil
    }

    // MARK: - Private playback

    private func playCurrentStage() {
        guard let regions = currentRegions, let audio = audioManager else { return }

        switch currentStage {
        case .stage1:
            audio.playStage1(
                filename: currentFilename,
                subdirectory: currentSubdirectory,
                region: regions.stage1
            )
        case .stage2:
            audio.playStage2(
                filename: currentFilename,
                subdirectory: currentSubdirectory,
                region: regions.stage2
            )
        case .stage3:
            audio.playStage3(
                filename: currentFilename,
                subdirectory: currentSubdirectory,
                region: regions.stage3
            ) { [weak self] in
                Task { @MainActor in
                    self?.advanceStage()
                }
            }
        case .replay:
            break
        }
    }
}
