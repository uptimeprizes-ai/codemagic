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

    /// The morning counted by a lock-screen answer, kept for the Prize
    /// screen if the person later opens the app and dismisses.
    private static var answeredOutcome: (day: String, outcome: AlarmEngine.MorningOutcome)?

    /// Today's lock-screen-counted morning, once; nil if there is none.
    static func consumeAnsweredOutcome(now: Date = Date()) -> AlarmEngine.MorningOutcome? {
        defer { answeredOutcome = nil }
        guard let saved = answeredOutcome, saved.day == MorningLedger.dayKey(for: now) else { return nil }
        return saved.outcome
    }

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
                // The morning already counted when it was answered.
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

        // Founder ruling 2026-09-26: answering the doorbell and hearing the
        // song counts the morning, whether or not the app is ever opened.
        // (A Dismiss more than 30 minutes late never reaches this point.)
        if let outcome = engine.handleAlarmDismissed(
            audioSounded: stages.audioSounded,
            stageAtDismiss: StageCoordinator.ruleName(for: stages.currentStage),
            reachedPrize: stages.currentStage == .stage3
        ) {
            answeredOutcome = (MorningLedger.dayKey(for: Date()), outcome)
        }
    }
}

extension AlarmEngine.MorningOutcome {
    /// The same morning, noting that the Prize has now been reached.
    func reachingPrize(_ reached: Bool) -> AlarmEngine.MorningOutcome {
        AlarmEngine.MorningOutcome(
            journeyTitle: journeyTitle,
            morningNumber: morningNumber,
            totalDays: totalDays,
            journeyComplete: journeyComplete,
            reachedPrize: reachedPrize || reached,
            heldStreakOnly: heldStreakOnly,
            wasUnanswered: wasUnanswered
        )
    }
}
