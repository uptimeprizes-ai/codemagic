import Foundation
import SwiftData

@Model
final class JourneyEntity {
    @Attribute(.unique) var id: String
    var title: String
    var descriptionText: String
    var type: String // "DEMO", "LIBRARY_A", "SIGNATURE"
    var totalDays: Int
    var isPurchaseOffered: Bool
    var isActive: Bool
    var purchaseState: String // "NOT_OWNED", "ACTIVE_IN_PROGRESS", "UNLOCKED_FOR_PLAYBACK"
    var completedDays: Int
    var currentDay: Int
    
    init(id: String, title: String, descriptionText: String, type: String, totalDays: Int, isPurchaseOffered: Bool, isActive: Bool, purchaseState: String, completedDays: Int, currentDay: Int) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.type = type
        self.totalDays = totalDays
        self.isPurchaseOffered = isPurchaseOffered
        self.isActive = isActive
        self.purchaseState = purchaseState
        self.completedDays = completedDays
        self.currentDay = currentDay
    }
}

@Model
final class SongEntity {
    @Attribute(.unique) var id: String
    var title: String
    var libraryId: String
    var dayNumber: Int
    var filename: String
    var isAvailable: Bool
    
    init(id: String, title: String, libraryId: String, dayNumber: Int, filename: String, isAvailable: Bool) {
        self.id = id
        self.title = title
        self.libraryId = libraryId
        self.dayNumber = dayNumber
        self.filename = filename
        self.isAvailable = isAvailable
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
