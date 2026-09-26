import Foundation

// MARK: - MorningStarter
//
// Build 33 experiment (founder, 2026-09-25, "option one"): a Dismiss on the
// AlarmKit lock screen starts the morning's song straight away, while the
// phone is still locked. The app's UI is not needed for that — it shows the
// running stage whenever the person opens it.
//
// The audio player and stage coordinator live here, one instance each, so
// the lock-screen intent and the app's screens drive the same morning.

@MainActor
enum MorningStarter {

    static let audio = AudioPlayerManager()
    static let stages = StageCoordinator()

    /// Starts today's song at the stage a snooze sent forward (the Invite
    /// otherwise). Does nothing if a morning is already playing; a morning
    /// that finished unseen is cleared first, so it can never block the next.
    static func startFromLockScreen() {
        guard !audio.isPlaying else { return }
        if stages.currentSong != nil { stages.stopAlarm() }
        let engine = AlarmEngine(context: UpTimePrizesApp.sharedContainer.mainContext)
        guard let song = engine.currentSong(from: audio) else {
            UpTimeLog.alarm.error("[ALARM] lock screen: no song for today — nothing to play")
            return
        }
        // Until the app's screen takes over, an unanswered ring ends the
        // same way it does in the app (Option B) — minus the on-screen note.
        stages.onRingLimit = { stage in
            switch RingDecision.onRingLimitReached(stage: stage, autoSnoozeUsed: engine.autoSnoozeUsed) {
            case .autoSnooze:
                engine.autoSnooze(stageAtSnooze: stage)
                stages.stopAlarm()
            case .stopAndReport:
                engine.endUnansweredSession()
                stages.stopAlarm()
            case .keepRinging:
                break
            }
        }
        stages.startAlarm(
            song: song,
            subdirectory: engine.subdirectory(for: song.journeyId),
            audioManager: audio,
            startingAt: StageCoordinator.stage(forRuleName: engine.consumeResumeStage())
        )
        UpTimeLog.alarm.notice("[ALARM] lock screen: morning started without opening the app")
    }
}
