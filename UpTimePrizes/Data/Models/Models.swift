import Foundation
import SwiftData

/// Identity is journeyId (`id`), never a journey "type". Metadata fields are
/// refreshed from the manifest on every launch where it changed; progress
/// fields (`isActive`, `purchaseState`, `completedDays`, `currentDay`) are
/// device state and are never overwritten by a manifest refresh.
@Model
final class JourneyEntity {
    @Attribute(.unique) var id: String // journeyId, e.g. "genesis", "cast-prelude"
    var title: String
    var descriptionText: String
    var framingLine: String = ""
    var totalDays: Int
    var sortOrder: Int = 0
    var packName: String = ""
    var productId: String = ""
    var entitlementId: String = ""
    var isPurchaseOffered: Bool
    var isActive: Bool
    var purchaseState: String // "NOT_OWNED", "ACTIVE_IN_PROGRESS", "UNLOCKED_FOR_PLAYBACK"
    var completedDays: Int
    var currentDay: Int // 1-based morning number; keeps moving after completion

    init(id: String, title: String, descriptionText: String, framingLine: String, totalDays: Int, sortOrder: Int, packName: String, productId: String, entitlementId: String, isPurchaseOffered: Bool, isActive: Bool, purchaseState: String, completedDays: Int, currentDay: Int) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.framingLine = framingLine
        self.totalDays = totalDays
        self.sortOrder = sortOrder
        self.packName = packName
        self.productId = productId
        self.entitlementId = entitlementId
        self.isPurchaseOffered = isPurchaseOffered
        self.isActive = isActive
        self.purchaseState = purchaseState
        self.completedDays = completedDays
        self.currentDay = currentDay
    }
}

/// Song rows are a projection of the manifest (regions stay manifest-only so
/// there is exactly one source of timing truth). Refreshed wholesale whenever
/// the manifest fingerprint changes.
@Model
final class SongEntity {
    @Attribute(.unique) var id: String
    var title: String
    var journeyId: String = ""
    var sortOrder: Int = 0
    var fileStem: String = "" // file name without extension; iOS plays <stem>.m4a
    var isAvailable: Bool

    init(id: String, title: String, journeyId: String, sortOrder: Int, fileStem: String, isAvailable: Bool) {
        self.id = id
        self.title = title
        self.journeyId = journeyId
        self.sortOrder = sortOrder
        self.fileStem = fileStem
        self.isAvailable = isAvailable
    }
}

/// One row per counted morning. A morning exists here only if audio actually
/// sounded — nothing played, nothing recorded. dayKey is unique, so a second
/// alarm on the same calendar day can never count twice, and the Android bug
/// of one session recording a morning twice cannot recur at the store level.
@Model
final class MorningRecordEntity {
    @Attribute(.unique) var dayKey: String // device-local "yyyy-MM-dd"
    var journeyId: String
    var stageAtDismiss: String // "invite" | "nudge" | "prize" | "autoSilence"
    var reachedPrize: Bool
    var heldStreakOnly: Bool // Catalyst morning (later: Genesis fallback) — holds the streak, extends nothing
    var advancedJourney: Bool
    var recordedAt: Date

    init(dayKey: String, journeyId: String, stageAtDismiss: String, reachedPrize: Bool, heldStreakOnly: Bool, advancedJourney: Bool, recordedAt: Date = Date()) {
        self.dayKey = dayKey
        self.journeyId = journeyId
        self.stageAtDismiss = stageAtDismiss
        self.reachedPrize = reachedPrize
        self.heldStreakOnly = heldStreakOnly
        self.advancedJourney = advancedJourney
        self.recordedAt = recordedAt
    }
}

@Model
final class DemoStateEntity {
    @Attribute(.unique) var id: String = "demo_state"
    var currentDay: Int
    var completedDays: Int
    var isPurchaseOffered: Bool
    var isActive: Bool
    
    init(currentDay: Int = 1, completedDays: Int = 0, isPurchaseOffered: Bool = false, isActive: Bool = true) {
        self.currentDay = currentDay
        self.completedDays = completedDays
        self.isPurchaseOffered = isPurchaseOffered
        self.isActive = isActive
    }
}

@Model
final class AlarmEntity {
    @Attribute(.unique) var id: String = "main_alarm"
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var repeatDays: [Int] // 1 = Sunday, 7 = Saturday
    
    init(hour: Int = 7, minute: Int = 0, isEnabled: Bool = false, repeatDays: [Int] = []) {
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
    }
}
