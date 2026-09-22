import Foundation

// MARK: - ReviewPromptManager
//
// The review prompt's eligibility rules (§2.6), kept pure so every rule is
// unit-testable. The caller supplies the live facts and performs the actual
// SKStoreReviewController/requestReview call from a normal app screen —
// never the alarm screen (Android bug guard 2: no permission-requiring or
// blocking calls on the alarm path).

struct ReviewPromptManager {

    static let requiredSoundedMornings = 5
    static let maxAttempts = 3
    static let attemptsKey = "com.uptimeprizes.reviewPromptAttempts"

    /// May the app ask for a review right now?
    /// - soundedMornings: total counted mornings (every counted morning sounded)
    /// - attemptsSoFar: how many times the app has asked before
    /// - lastCountedMorningIsRecent: last counted morning was today or yesterday
    /// - alarmActive / audioPlaying: it must never ask during either
    /// - hasUnacknowledgedMissedAlarm: from the missed-alarm pass; false until
    ///   that lands (§2.7)
    static func shouldAsk(
        soundedMornings: Int,
        attemptsSoFar: Int,
        lastCountedMorningIsRecent: Bool,
        alarmActive: Bool,
        audioPlaying: Bool,
        hasUnacknowledgedMissedAlarm: Bool
    ) -> Bool {
        guard soundedMornings >= requiredSoundedMornings else { return false }
        guard attemptsSoFar < maxAttempts else { return false }
        guard lastCountedMorningIsRecent else { return false }
        guard !alarmActive, !audioPlaying else { return false }
        guard !hasUnacknowledgedMissedAlarm else { return false }
        return true
    }

    // MARK: - Attempt bookkeeping (UserDefaults)

    static func attempts(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: attemptsKey)
    }

    static func recordAttempt(defaults: UserDefaults = .standard) {
        defaults.set(attempts(defaults: defaults) + 1, forKey: attemptsKey)
    }
}
