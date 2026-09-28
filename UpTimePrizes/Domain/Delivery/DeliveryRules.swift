import Foundation

// MARK: - DeliveryState
//
// Where a journey's music is (Android JourneyDownload). The Genesis ships
// inside the app; every paid journey downloads after purchase as its own
// Apple-hosted asset pack, named by its journeyId (delivery memo, 26 Sept).

enum DeliveryState: Equatable {
    /// The music ships inside the app.
    case inApp
    /// Downloaded and playable.
    case ready
    /// Owned, not on this phone yet.
    case notDownloaded
    /// Downloading; 0…1.
    case arriving(Double)
    /// Paused by the system — most often waiting for Wi-Fi.
    case waitingForWiFi
    /// The download failed.
    case didNotArrive

    var isPlayable: Bool { self == .inApp || self == .ready }
}

// MARK: - DeliveryLabel
//
// The line on a Discover card, in Android's shipping words
// (JourneyDownloadLabel). Nil when there is nothing to say: the music is in
// the app, it is already here, or the person does not own the journey.

enum DeliveryLabel {

    static func text(_ state: DeliveryState, owned: Bool) -> String? {
        guard owned else { return nil }
        switch state {
        case .inApp, .ready:
            return nil
        case .arriving(let progress):
            return "Arriving · \(Int(min(max(progress, 0), 1) * 100))%"
        case .waitingForWiFi:
            return "Waiting for Wi-Fi"
        case .didNotArrive:
            return "Did not arrive — tap to try again"
        case .notDownloaded:
            return "Tap to download"
        }
    }

    /// True when tapping the card should start (or restart) the download.
    static func isActionable(_ state: DeliveryState, owned: Bool) -> Bool {
        guard owned else { return false }
        switch state {
        case .notDownloaded, .didNotArrive, .waitingForWiFi:
            return true
        case .inApp, .ready, .arriving:
            return false
        }
    }
}

// MARK: - GenesisFallback
//
// A morning whose song has not arrived plays a Genesis song instead, never
// silence. The streak counts; the journey does not move (Android
// AlarmMorningPolicy: a fallback is recorded like a Catalyst morning).

enum GenesisFallback {
    /// Which Genesis morning stands in, rotating with the journey's day.
    static func morning(forJourneyDay currentDay: Int, genesisSongCount: Int) -> Int {
        guard genesisSongCount > 0 else { return 1 }
        return (max(currentDay, 1) - 1) % genesisSongCount + 1
    }
}
