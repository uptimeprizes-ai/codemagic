import Foundation

// MARK: - CatalogRules
//
// What the Player shows, from the Android screen map (App Builder,
// 2026-09-25). Pure, so every rule is unit-tested. The vocabulary — pills,
// "DAY n / N", "COMPLETE" — is the shipping Android copy, quoted there.
//
//   1. Nothing purchasable is visible before the ninth COUNTED Genesis
//      morning: the catalog section is hidden entirely until then.
//   2. A journey's songs are listed only when that journey is finished
//      (UNLOCKED_FOR_PLAYBACK) — except the Catalyst Tracks, listed the
//      moment they are owned.
//   3. Every catalog row carries a state pill.
//   4. COMPLETE stands alone on the day pill (curator) — never with a name,
//      and a counter past the end (DAY 33 / 9) can never print.

enum CatalogRules {

    static let genesisId = "genesis"
    static let catalystId = "catalyst"
    static let gateMornings = 9

    struct JourneyFacts: Equatable {
        let id: String
        let totalDays: Int
        let completedDays: Int
        let isActive: Bool
        let purchaseState: String
        let sortOrder: Int

        var isOwned: Bool { purchaseState != "NOT_OWNED" }
        var isComplete: Bool { purchaseState == "UNLOCKED_FOR_PLAYBACK" || completedDays >= totalDays }
    }

    /// The catalog opens after the ninth COUNTED Genesis morning.
    static func isCatalogOpen(genesisCompletedDays: Int) -> Bool {
        genesisCompletedDays >= gateMornings
    }

    /// Rows in the Player's catalog: The Genesis first, then every owned
    /// journey in manifest sortOrder. Empty while the gate is closed.
    static func catalogRows(_ journeys: [JourneyFacts], genesisCompletedDays: Int) -> [JourneyFacts] {
        guard isCatalogOpen(genesisCompletedDays: genesisCompletedDays) else { return [] }
        let genesis = journeys.filter { $0.id == genesisId }
        let owned = journeys
            .filter { $0.id != genesisId && $0.isOwned }
            .sorted { $0.sortOrder < $1.sortOrder }
        return genesis + owned
    }

    /// Whether a journey's song list may appear.
    static func songsVisible(_ journey: JourneyFacts) -> Bool {
        if journey.id == catalystId { return journey.isOwned }
        return journey.purchaseState == "UNLOCKED_FOR_PLAYBACK"
    }

    /// The state pill on a catalog row.
    static func rowPill(_ journey: JourneyFacts) -> String {
        if journey.id == catalystId { return "Owned" }
        if journey.isComplete { return "Complete" }
        if journey.id == genesisId && journey.completedDays == 0 { return "Free" }
        if journey.isActive || journey.id == genesisId {
            return "Day \(journey.completedDays + 1) of \(journey.totalDays)"
        }
        return "Owned"
    }

    /// The Player's day pill for the active journey.
    static func dayPill(_ journey: JourneyFacts) -> String {
        if journey.isComplete { return "COMPLETE" }
        return "DAY \(journey.completedDays + 1) / \(journey.totalDays)"
    }
}

extension CatalogRules.JourneyFacts {
    init(_ entity: JourneyEntity) {
        self.init(
            id: entity.id,
            totalDays: entity.totalDays,
            completedDays: entity.completedDays,
            isActive: entity.isActive,
            purchaseState: entity.purchaseState,
            sortOrder: entity.sortOrder
        )
    }
}
