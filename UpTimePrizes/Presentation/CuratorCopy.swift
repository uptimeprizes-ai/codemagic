import Foundation

// MARK: - CuratorCopy
//
// Every user-facing string the curator has ruled, verbatim (handoff §2.9).
// Nothing here may be edited without a new curator ruling. As of the
// 2026-10-09 ruling no un-ruled string remains. If one is ever added again
// it must carry the pending marker, because a marked string is the only
// thing that stops un-ruled words being mistaken for approved copy.
//
// Standing rules: "sounded", never "rang"; never "failed" or "error" in a
// download or playback state; the Prize screen says only what is now true.

enum CuratorCopy {

    // MARK: Prize screen (§2.5, §2.9)

    static let prizeMessagePrizeReached =
        "The song itself, the UpTime swing — and the morning is yours."
    static let prizeMessageDismissedEarly =
        "The morning is yours. Tomorrow brings another song."
    static let prizeMessageJourneyComplete =
        "That is the whole journey. Every song is now yours to play whenever you want."
    static let prizeMessageCatalystOrFallback =
        "A song for today. Your journey is exactly where you left it."
    static let prizeContinue = "Continue" // §2.5: "Continue" returns to the app

    /// Curator, 2026-09-23 — a morning nobody answered leads the message,
    /// before anything else, and where the line underneath carries a fact of
    /// its own the two STACK (unheard line first) rather than one replacing
    /// the other.
    ///
    /// Reworded 2026-10-09. The original second clause read "The morning
    /// still counts." Founder ruling 2026-09-25 made that false. That ruling
    /// retired its twin in missedAlarmSoundedBody but missed this one, which
    /// has five callers and ships. The replacement states the same
    /// reassurance truthfully, and repeats the wording of neither line it
    /// stacks above.
    static let prizeMessageUnheard =
        "That one played without you. Nothing was lost."

    // MARK: Claim (§2.8) — used by the gift path when it lands

    static func claimSuccess(journeyTitle: String) -> String {
        "\(journeyTitle) is yours."
    }

    // MARK: Missed alarm (§2.7) — used by the missed-alarm pass when it lands

    static let missedAlarmTitle = "Missed alarm"
    /// Ruled 2026-09-17 but NO LONGER TRUE: founder ruling 2026-09-25 -
    /// an unanswered alarm does not count. Kept only as the record of the
    /// retired line; never shown. See missedAlarmSoundedUnansweredBody.
    static let missedAlarmSoundedBody = "The alarm sounded. The morning counts."
    static let missedAlarmSilentBody = "The alarm did not sound. Your phone may have blocked it."

    // MARK: Player

    static let songNotReady = "NOT READY YET · This one is still arriving."
    static let journeyCompletePill = "COMPLETE" // alone; no journey name

    // MARK: Discover
    //
    // No price is ever stored in the app: every figure comes from the App
    // Store (Product.displayPrice). Pricing canon, 1 Oct 2026.

    // MARK: Settings

    static let snoozeSubtitle = "How long before the alarm returns"

    // MARK: Downloads (§2.9) — used by the delivery pass when it lands

    static func downloadArriving(percent: Int) -> String { "Arriving · \(percent)%" }
    static let downloadWaitingForWiFi = "Waiting for Wi-Fi"
    static let downloadDidNotArrive = "Did not arrive — tap to try again"
    static let downloadNeeded = "Tap to download"
    static func giftClaimedDownloading(journeyTitle: String) -> String {
        "\(journeyTitle) is yours. Arriving now."
    }

    // MARK: Alarm surfaces — ruled 2026-10-09

    /// The AlarmKit alert title, shown full-screen beside "Dismiss" at wake
    /// time. At that moment the screen's whole job is to identify itself, so
    /// it carries the name and nothing clever. The voice belongs on the
    /// Prize screen, which the user reaches awake.
    static let alarmAlertTitle = "UpTime Prizes"

    /// Body of the local alarm notification.
    static let alarmNotificationBody = "Your morning is ready."

    /// Sounded, nobody answered, and by founder ruling 2026-09-25 the
    /// morning does not count — so the line says the alarm sounded (never
    /// "rang") and then says what the user actually wants to know: that
    /// nothing moved. Second clause is the ruled wording of
    /// prizeMessageCatalystOrFallback, deliberately.
    static let missedAlarmSoundedUnansweredBody =
        "The alarm sounded without you. Your journey is exactly where you left it."
}
