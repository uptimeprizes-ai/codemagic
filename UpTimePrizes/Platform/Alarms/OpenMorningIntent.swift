import Foundation
import AppIntents

#if canImport(AlarmKit)
import AlarmKit

// MARK: - OpenMorningIntent
//
// Runs when the person taps Dismiss on the AlarmKit lock-screen alarm. It
// stops the ring and opens the app into the morning — the Option 2 shape:
// the morning begins on the lock screen and completes in the app, where the
// song plays, the morning counts, and the Prize screen appears.
//
// The start request is persisted as well as posted: when the tap cold-
// launches the app, the post can land before the UI is listening, so the
// app also consumes the persisted request once it is ready. A request is
// honoured only while fresh, so a stale tap can never start a later morning.

@available(iOS 26.0, *)
struct OpenMorningIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open the morning"
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        try? AlarmManager.shared.stop(id: AlarmKitScheduler.alarmUUID)
        PendingMorningStart.record()
        await MainActor.run {
            UpTimeLog.alarm.notice("[ALARM] AlarmKit dismissed — opening the morning")
            NotificationCenter.default.post(name: AlarmEngine.alarmFiredNotificationName, object: nil)
        }
        return .result()
    }
}
#endif

// MARK: - PendingMorningStart

enum PendingMorningStart {
    private static let key = "com.uptimeprizes.pendingMorningStart"
    private static let freshness: TimeInterval = 10 * 60

    static func record(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: key)
    }

    /// True once if a fresh request is waiting; clears it either way.
    static func consume(now: Date = Date()) -> Bool {
        let stamp = UserDefaults.standard.double(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        guard stamp > 0 else { return false }
        return now.timeIntervalSince1970 - stamp <= freshness
    }
}
