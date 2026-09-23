import Foundation

// MARK: - RingDecision (Option B — founder, 2026-09-15)
//
// The decision is a pure object with no platform in it — stage in, action
// out — mirroring the Android shape so both platforms argue from the same
// table. The limit belongs to the ringing SESSION, not the screen.
//
//   Ring        | Nobody answers for 7 minutes
//   ------------|--------------------------------------------------------
//   The Invite  | Auto-snooze ONCE, at the person's own gap. Nudge returns.
//   The Nudge   | Stop. The morning counts, because it sounded. Report.
//   The Prize   | Untouched — plays out and waits, until a 30-min backstop.
//
// One auto-snooze per alarm, persisted — the process can die between rings.
// Stages never advance on their own; a stage moves when someone snoozes,
// or when the app snoozes for them.

enum RingAction: Equatable {
    case keepRinging
    case autoSnooze     // through the SAME path as a person's own snooze
    case stopAndReport  // the morning counts (it sounded); report it
}

enum RingDecision {

    /// One ring lasts seven minutes unanswered.
    static let ringLimitSeconds: TimeInterval = 7 * 60

    /// The Prize stage's backstop: left alone entirely, the alarm ends
    /// itself after 30 minutes and the morning counts as auto-silence.
    static let prizeBackstopSeconds: TimeInterval = 30 * 60

    /// What happens when a stage's ring limit is reached.
    static func onRingLimitReached(stage: String, autoSnoozeUsed: Bool) -> RingAction {
        switch stage {
        case "invite":
            return autoSnoozeUsed ? .stopAndReport : .autoSnooze
        case "nudge":
            return .stopAndReport
        default:
            // The Prize is never cut short by the 7-minute rule; only the
            // backstop ends it, and the caller treats that as auto-silence.
            return .keepRinging
        }
    }

    /// The ring limit for a stage — seven minutes for the ringing stages,
    /// the backstop for the Prize and Replay.
    static func limitSeconds(forStage stage: String) -> TimeInterval {
        stage == "invite" || stage == "nudge" ? ringLimitSeconds : prizeBackstopSeconds
    }
}
