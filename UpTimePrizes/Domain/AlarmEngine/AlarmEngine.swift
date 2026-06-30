import Foundation
import UserNotifications
import SwiftData

// MARK: - AlarmEngine

/// Manages alarm scheduling via UNUserNotificationCenter and handles
/// day progression when the alarm is dismissed.
@MainActor
class AlarmEngine: ObservableObject {

    // MARK: - Constants

    static let alarmNotificationIdentifier = "com.uptimeprizes.alarm.morning"
    static let alarmFiredNotificationName = Notification.Name("UpTimePrizesAlarmFired")

    // MARK: - Published state

    @Published var isAlarmActive: Bool = false

    // MARK: - Private

    private let context: ModelContext

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Permission

    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[AlarmEngine] Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Schedule

    /// Schedule a local notification for the alarm.
    /// - Parameters:
    ///   - hour: Hour in 24h format
    ///   - minute: Minute
    ///   - repeatDays: Array of weekday integers (1 = Sunday … 7 = Saturday). Empty = daily.
    func scheduleAlarm(hour: Int, minute: Int, repeatDays: [Int]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.alarmNotificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Good morning."
        content.body = "Your morning experience is ready."
        content.sound = UNNotificationSound.default
        content.userInfo = ["type": "alarm"]

        if repeatDays.isEmpty {
            // Daily alarm
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.alarmNotificationIdentifier,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error = error {
                    print("[AlarmEngine] Failed to schedule daily alarm: \(error)")
                }
            }
        } else {
            // Per-weekday alarms
            for weekday in repeatDays {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "\(Self.alarmNotificationIdentifier)_\(weekday)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                center.add(request) { error in
                    if let error = error {
                        print("[AlarmEngine] Failed to schedule alarm for weekday \(weekday): \(error)")
                    }
                }
            }
        }
    }

    func cancelAlarm() {
        let center = UNUserNotificationCenter.current()
        // Cancel base identifier + all weekday variants
        var identifiers = [Self.alarmNotificationIdentifier]
        for weekday in 1...7 {
            identifiers.append("\(Self.alarmNotificationIdentifier)_\(weekday)")
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Reschedule from persisted state

    /// Called on app launch to restore alarm scheduling from AlarmEntity.
    func rescheduleFromPersistedState() {
        let fetchAlarm = FetchDescriptor<AlarmEntity>()
        guard let alarm = try? context.fetch(fetchAlarm).first, alarm.isEnabled else { return }
        scheduleAlarm(hour: alarm.hour, minute: alarm.minute, repeatDays: alarm.repeatDays)
    }

    // MARK: - Day progression

    /// Called when the user dismisses the alarm at any stage.
    /// Increments completedDays and currentDay on the active journey.
    /// Sets purchaseState to UNLOCKED_FOR_PLAYBACK when journey is complete.
    func handleAlarmDismissed() {
        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard let journeys = try? context.fetch(fetchJourneys),
              let active = journeys.first(where: { $0.isActive }) else {
            return
        }

        // Increment progress
        active.completedDays += 1

        // Check if journey is complete
        if active.completedDays >= active.totalDays {
            active.purchaseState = "UNLOCKED_FOR_PLAYBACK"
        }

        // Advance currentDay (cycles through totalDays for DEMO type)
        if active.type == "DEMO" {
            // Genesis has 5 songs but 9 days — cycle through songs
            let songCount = 5
            active.currentDay = (active.currentDay % songCount) + 1
        } else {
            active.currentDay = min(active.currentDay + 1, active.totalDays)
        }

        // Also update DemoState if active journey is DEMO
        if active.type == "DEMO" {
            let fetchDemo = FetchDescriptor<DemoStateEntity>()
            if let demo = try? context.fetch(fetchDemo).first {
                demo.completedDays = active.completedDays
                demo.currentDay = active.currentDay
                // Unlock Discover page after 9 days
                if demo.completedDays >= 9 {
                    demo.isPurchaseOffered = true
                }
            }
        }

        try? context.save()
        isAlarmActive = false
    }

    // MARK: - Song resolution

    /// Returns the song to play for the currently active journey.
    func currentSong(from audioManager: AudioPlayerManager) -> ManifestSong? {
        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard let journeys = try? context.fetch(fetchJourneys),
              let active = journeys.first(where: { $0.isActive }) else {
            return nil
        }

        let libraryId = active.id
        let dayNumber = active.currentDay
        return audioManager.song(for: libraryId, dayNumber: dayNumber)
    }

    /// Returns the subdirectory for bundled audio files.
    func subdirectory(for journeyId: String) -> String? {
        switch journeyId {
        case "demo": return "demo"
        default: return nil // paid content downloaded to documents directory
        }
    }
}
