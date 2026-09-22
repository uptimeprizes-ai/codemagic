import Foundation
import UserNotifications
import SwiftData

// MARK: - AlarmEngine

/// Manages alarm scheduling via UNUserNotificationCenter and handles
/// day progression when the alarm is dismissed.
///
/// Defensive recovery principle (Bug 1 fix): On every app activation,
/// verify the alarm is still scheduled. If the user has an enabled alarm
/// but no pending notification exists, re-schedule immediately.
@MainActor
class AlarmEngine: ObservableObject {

    // MARK: - Constants

    static let alarmNotificationIdentifier = "com.uptimeprizes.alarm.morning"
    static let alarmFiredNotificationName = Notification.Name("UpTimePrizesAlarmFired")

    // The curator has not ruled copy for the alarm notification; the marked
    // placeholders live in CuratorCopy with everything else user-facing.
    static let placeholderAlarmTitle = CuratorCopy.placeholderAlarmNotificationTitle
    static let placeholderAlarmBody = CuratorCopy.placeholderAlarmNotificationBody

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
        center.removePendingNotificationRequests(withIdentifiers: allAlarmIdentifiers())

        let content = UNMutableNotificationContent()
        content.title = Self.placeholderAlarmTitle
        content.body = Self.placeholderAlarmBody
        content.sound = UNNotificationSound.default
        content.userInfo = ["type": "alarm"]

        if repeatDays.isEmpty {
            // Daily alarm
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: alarmNotificationIdentifier,
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
                let identifier = "\(alarmNotificationIdentifier)_\(weekday)"
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
        center.removePendingNotificationRequests(withIdentifiers: allAlarmIdentifiers())
    }

    // MARK: - Bug 1 Fix: Defensive re-arm on every app activation

    /// Called on every app launch AND every time the app becomes active.
    /// Verifies that a pending alarm notification exists for enabled alarms.
    /// If the alarm is enabled but no notification is pending (e.g., wiped by
    /// an app update or OS event), silently re-schedules it.
    func verifyAndRescheduleIfNeeded() async {
        let fetchAlarm = FetchDescriptor<AlarmEntity>()
        guard let alarm = try? context.fetch(fetchAlarm).first, alarm.isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let alarmIds = Set(allAlarmIdentifiers())
        let hasScheduled = pending.contains { alarmIds.contains($0.identifier) }

        if !hasScheduled {
            print("[AlarmEngine] Alarm was enabled but no pending notification found — re-scheduling.")
            scheduleAlarm(hour: alarm.hour, minute: alarm.minute, repeatDays: alarm.repeatDays)
        }
    }

    /// Called on initial launch to restore alarm scheduling from AlarmEntity.
    func rescheduleFromPersistedState() {
        let fetchAlarm = FetchDescriptor<AlarmEntity>()
        guard let alarm = try? context.fetch(fetchAlarm).first, alarm.isEnabled else { return }
        scheduleAlarm(hour: alarm.hour, minute: alarm.minute, repeatDays: alarm.repeatDays)
    }

    // MARK: - Day progression

    /// One recorded morning per alarm session (§2.4). Reset when a new alarm
    /// session begins; checked before any counting. Android recorded a
    /// morning twice when Continue was tapped — this latch and the ledger's
    /// unique dayKey both forbid it.
    private var hasCountedThisSession = false

    /// Call when a new alarm session begins (the alarm UI is presented).
    func beginAlarmSession() {
        hasCountedThisSession = false
        isAlarmActive = true
    }

    /// Everything the Prize screen needs about a counted morning.
    struct MorningOutcome {
        let journeyTitle: String
        let morningNumber: Int   // completedDays after counting
        let totalDays: Int
        let journeyComplete: Bool
        let reachedPrize: Bool
        let heldStreakOnly: Bool // Catalyst morning (later: Genesis fallback)
    }

    /// Called when the user dismisses the alarm (any stage), or auto-silence
    /// ends it. Returns the outcome if the morning counted, nil if it did not
    /// (no Prize screen without a counted morning, §2.5).
    ///
    /// The rules (§2.4):
    /// - counts only if audio actually sounded;
    /// - one morning per calendar day (ledger-enforced);
    /// - one recorded morning per alarm session (session latch);
    /// - a Catalyst morning holds the streak and advances no journey;
    /// - the morning index keeps moving after completion, wrapping at lookup.
    func handleAlarmDismissed(audioSounded: Bool, stageAtDismiss: String, reachedPrize: Bool, date: Date = Date()) -> MorningOutcome? {
        defer { isAlarmActive = false }

        guard audioSounded else { return nil } // nothing played → nothing counted
        guard !hasCountedThisSession else { return nil }

        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard let journeys = try? context.fetch(fetchJourneys),
              let active = journeys.first(where: { $0.isActive }) else {
            return nil
        }

        let ledger = MorningLedger(context: context)
        let isCatalyst = active.id == "catalyst"

        let counted = ledger.record(
            date: date,
            journeyId: active.id,
            stageAtDismiss: stageAtDismiss,
            reachedPrize: reachedPrize,
            heldStreakOnly: isCatalyst,
            advancedJourney: !isCatalyst
        )
        guard counted else { return nil } // this calendar day already has its morning

        hasCountedThisSession = true

        if !isCatalyst {
            active.completedDays += 1
            active.currentDay += 1

            if active.completedDays >= active.totalDays {
                active.purchaseState = "UNLOCKED_FOR_PLAYBACK"
            }

            // Genesis progress also drives the Discover unlock: the store
            // opens after the 9th Genesis morning is counted.
            if active.id == "genesis" {
                let fetchDemo = FetchDescriptor<DemoStateEntity>()
                if let demo = try? context.fetch(fetchDemo).first {
                    demo.completedDays = active.completedDays
                    demo.currentDay = active.currentDay
                    if demo.completedDays >= 9 {
                        demo.isPurchaseOffered = true
                    }
                }
            }
        }

        try? context.save()

        return MorningOutcome(
            journeyTitle: active.title,
            morningNumber: active.completedDays,
            totalDays: active.totalDays,
            journeyComplete: !isCatalyst && active.completedDays >= active.totalDays,
            reachedPrize: reachedPrize,
            heldStreakOnly: isCatalyst
        )
    }

    // MARK: - Song resolution

    /// Returns the song to play for the currently active journey's morning,
    /// wrapping round the journey's song list.
    func currentSong(from audioManager: AudioPlayerManager) -> ManifestSong? {
        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard let journeys = try? context.fetch(fetchJourneys),
              let active = journeys.first(where: { $0.isActive }) else {
            return nil
        }
        return audioManager.song(forJourneyId: active.id, morning: active.currentDay)
    }

    /// Bundle subdirectory for a journey's audio. Only The Genesis ships
    /// inside the app; its files currently live in the legacy Audio/demo
    /// folder until the pipeline's iOS set replaces them (step 5). Every
    /// other journey's audio arrives by download.
    func subdirectory(for journeyId: String) -> String? {
        journeyId == "genesis" ? "demo" : nil
    }

    // MARK: - Private helpers

    private var alarmNotificationIdentifier: String { Self.alarmNotificationIdentifier }

    private func allAlarmIdentifiers() -> [String] {
        var ids = [Self.alarmNotificationIdentifier]
        for weekday in 1...7 {
            ids.append("\(Self.alarmNotificationIdentifier)_\(weekday)")
        }
        return ids
    }
}

// MARK: - Snooze extension

extension AlarmEngine {

    /// Default snooze duration in minutes
    static let snoozeDurationMinutes: Int = 9

    /// Snooze the alarm: stop audio, schedule a one-time notification
    /// snoozeDurationMinutes from now, and dismiss the alarm UI.
    func snoozeAlarm() {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = Self.placeholderAlarmTitle
        content.body = Self.placeholderAlarmBody
        content.sound = UNNotificationSound.default
        content.userInfo = ["type": "alarm"]

        // Fire once after snooze duration
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(Self.snoozeDurationMinutes * 60),
            repeats: false
        )
        let snoozeId = "\(Self.alarmNotificationIdentifier).snooze"
        center.removePendingNotificationRequests(withIdentifiers: [snoozeId])
        let request = UNNotificationRequest(identifier: snoozeId, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("[AlarmEngine] Failed to schedule snooze: \(error)")
            }
        }

        isAlarmActive = false
        // Note: snooze does NOT increment completedDays — only Dismiss does
    }
}
