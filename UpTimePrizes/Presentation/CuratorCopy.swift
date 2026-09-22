import Foundation

// MARK: - CuratorCopy
//
// Every user-facing string the curator has ruled, verbatim (handoff §2.9).
// Nothing here may be edited without a new curator ruling. Strings marked
// [COPY PENDING] have no ruling yet and must not survive into a public
// release; they are deliberately visible so un-ruled words are never
// mistaken for approved copy.
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

    // MARK: Claim (§2.8) — used by the gift path when it lands

    static func claimSuccess(journeyTitle: String) -> String {
        "\(journeyTitle) is yours."
    }

    // MARK: Missed alarm (§2.7) — used by the missed-alarm pass when it lands

    static let missedAlarmTitle = "Missed alarm"
    static let missedAlarmSoundedBody = "The alarm sounded. The morning counts."
    static let missedAlarmSilentBody = "The alarm did not sound. Your phone may have blocked it."

    // MARK: Player

    static let songNotReady = "NOT READY YET · This one is still arriving."
    static let journeyCompletePill = "COMPLETE" // alone; no journey name

    // MARK: Discover

    static let discoverPriceLine = "JOURNEYS FROM $1.99"

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

    // MARK: Un-ruled — placeholders awaiting the curator

    static let placeholderAlarmNotificationTitle = "[COPY PENDING] Alarm"
    static let placeholderAlarmNotificationBody = "[COPY PENDING] Open UpTime Prizes to begin the morning."
}
