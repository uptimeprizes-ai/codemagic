import Foundation

// MARK: - CatalogRules
//
// What the Player shows, from the Android screen map (App Builder,
// 2026-09-25) and the shipping Android code it describes (PlayerPage.kt,
// PlayerPageViewModel.kt, CatalogComponents.kt). Pure, so every rule is
// unit-tested. The vocabulary is the shipping Android copy.
//
//   1. Nothing purchasable is visible before the ninth COUNTED Genesis
//      morning — and even after it, the catalog section appears only once
//      the person owns something.
//   2. A journey's songs are listed only when that journey is finished
//      (UNLOCKED_FOR_PLAYBACK) — except the Catalyst Tracks, listed the
//      moment they are owned. The Genesis row never lists songs.
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
        var isComplete: Bool { totalDays > 0 && completedDays >= totalDays }
    }

    enum PillStyle: Equatable {
        case active, owned, price
    }

    struct Pill: Equatable {
        let label: String
        let style: PillStyle
    }

    // MARK: Gate

    /// The catalog opens after the ninth COUNTED Genesis morning.
    static func isCatalogOpen(genesisCompletedDays: Int) -> Bool {
        genesisCompletedDays >= gateMornings
    }

    /// Owned journeys with their own catalog row: not The Genesis (it has a
    /// fixed row) and not the Catalyst Tracks (rendered last), in sortOrder.
    static func ownedRows(_ journeys: [JourneyFacts]) -> [JourneyFacts] {
        journeys
            .filter { $0.id != genesisId && $0.id != catalystId && $0.isOwned }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func isCatalystOwned(_ journeys: [JourneyFacts]) -> Bool {
        journeys.contains { $0.id == catalystId && $0.isOwned }
    }

    /// The whole CATALOG section: gate open AND something owned.
    static func showsCatalog(_ journeys: [JourneyFacts], genesisCompletedDays: Int) -> Bool {
        isCatalogOpen(genesisCompletedDays: genesisCompletedDays)
            && (!ownedRows(journeys).isEmpty || isCatalystOwned(journeys))
    }

    /// Whether a journey's song list may appear.
    static func songsVisible(_ journey: JourneyFacts) -> Bool {
        if journey.id == genesisId { return false }
        if journey.id == catalystId { return journey.isOwned }
        return journey.purchaseState == "UNLOCKED_FOR_PLAYBACK"
    }

    // MARK: Pills

    /// The Genesis row: Free before its first counted morning, then
    /// "Day n of 9", then Complete once the ninth is behind it.
    static func genesisPill(completedDays: Int, currentDay: Int, isActive: Bool) -> Pill {
        guard isActive, completedDays > 0 else { return Pill(label: "Free", style: .price) }
        if currentDay > gateMornings { return Pill(label: "Complete", style: .active) }
        return Pill(label: "Day \(currentDay) of \(gateMornings)", style: .active)
    }

    /// An owned journey's row. iOS has no separate "owned, not active"
    /// state: an in-progress journey that is not the active one reads Owned.
    static func journeyPill(_ journey: JourneyFacts) -> Pill {
        switch journey.purchaseState {
        case "UNLOCKED_FOR_PLAYBACK":
            return Pill(label: "Complete", style: .owned)
        case "ACTIVE_IN_PROGRESS":
            return journey.isActive
                ? Pill(label: "Active", style: .active)
                : Pill(label: "Owned", style: .owned)
        default:
            return Pill(label: "Owned", style: .owned)
        }
    }

    // MARK: Day pill

    /// The morning the person is on. The Genesis uses its own counter; any
    /// other journey shows the next morning until today's has been counted.
    static func dayCount(_ journey: JourneyFacts, genesisCurrentDay: Int, countedToday: Bool) -> Int {
        if journey.id == genesisId { return genesisCurrentDay }
        if countedToday { return journey.completedDays }
        return min(journey.completedDays + 1, journey.totalDays)
    }

    static func dayPill(_ journey: JourneyFacts, dayCount: Int) -> String {
        journey.isComplete ? "COMPLETE" : "DAY \(dayCount) / \(journey.totalDays)"
    }

    /// The journey progress bar under the Morning Prize player.
    static func progress(dayCount: Int, totalDays: Int) -> Double {
        guard totalDays > 0 else { return 0 }
        return min(max(Double(dayCount) / Double(totalDays), 0), 1)
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
