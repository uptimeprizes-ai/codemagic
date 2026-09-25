import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit

// MARK: - AlarmKitScheduler (Option 2 — founder, 2026-09-23)
//
// On iOS 26+ the morning is rung by AlarmKit: a real system alarm that
// breaks through the silent switch and Focus, snoozes at the person's own
// gap, and — because an authorized AlarmKit alarm always sounds — makes
// "the morning counts because it sounded" an honest statement even when
// nobody answers. Devices below iOS 26 keep the notification path.
//
// Sound: the system default until the pipeline delivers per-song alert
// excerpts (≤30 s hard cap; loop1 cuts trimmed to fit). Never cut here.

@available(iOS 26.0, *)
nonisolated struct UpTimeAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
@MainActor
enum AlarmKitScheduler {

    /// One morning alarm, one stable identity.
    static let alarmUUID = UUID(uuidString: "0B5E5EAD-0000-4000-8000-C0FFEE000001")!

    static var isAuthorized: Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    /// Ask once; the system remembers. Returns whether alarms may ring.
    static func requestAuthorization() async -> Bool {
        let before = AlarmManager.shared.authorizationState
        UpTimeLog.alarm.notice("[ALARM] AlarmKit authorization before request: \(String(describing: before), privacy: .public)")
        switch before {
        case .authorized:
            return true
        case .notDetermined:
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                UpTimeLog.alarm.notice("[ALARM] AlarmKit authorization after request: \(String(describing: state), privacy: .public)")
                return state == .authorized
            } catch {
                UpTimeLog.alarm.error("[ALARM] AlarmKit authorization request threw: \(String(reflecting: error), privacy: .public)")
                return false
            }
        default:
            return false
        }
    }

    /// 1 = Sunday … 7 = Saturday (AlarmEntity's convention) → Locale.Weekday.
    static func weekdays(from repeatDays: [Int]) -> [Locale.Weekday] {
        let map: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        let days = repeatDays.compactMap { map[$0] }
        // Empty = every day, matching the notification path's daily alarm.
        return days.isEmpty ? [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday] : days
    }

    /// Schedule (or replace) the morning alarm.
    ///
    /// ALERT-ONLY for now. Build 124 asked AlarmKit for a snooze countdown
    /// (countdownDuration.postAlert + secondaryButtonBehavior .countdown) and
    /// scheduling failed on device with com.apple.AlarmKit.Alarm Code=0.
    /// AlarmKit expects a widget extension providing Live Activity UI for any
    /// countdown presentation, and this app has none. An alert-only alarm
    /// needs no extension. Lock-screen snooze returns once the extension
    /// exists (it needs its own App ID and provisioning profile — the
    /// founder's account action, never the agent's).
    static func schedule(hour: Int, minute: Int, repeatDays: [Int], snoozeMinutes: Int) async throws {
        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdays(from: repeatDays))
        let schedule = Alarm.Schedule.relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))

        // "Dismiss" is the specification's own word; the alert title is the
        // marked placeholder until the curator rules.
        let stopButton = AlarmButton(
            text: "Dismiss",
            textColor: .white,
            systemImageName: "stop.circle"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: CuratorCopy.placeholderAlarmNotificationTitle),
            stopButton: stopButton
        )
        let attributes = AlarmAttributes<UpTimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color("brass")
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes
        )

        // Replace, never stack: cancel any alarm already holding our id.
        try? AlarmManager.shared.cancel(id: alarmUUID)

        do {
            _ = try await AlarmManager.shared.schedule(id: alarmUUID, configuration: configuration)
        } catch {
            UpTimeLog.alarm.error("[ALARM] AlarmKit schedule threw: \(String(reflecting: error), privacy: .public)")
            throw error
        }
        UpTimeLog.alarm.notice("[ALARM] AlarmKit scheduled \(hour, privacy: .public):\(String(format: "%02d", minute), privacy: .public) alert-only")
    }

    static func cancel() {
        try? AlarmManager.shared.cancel(id: alarmUUID)
    }
}
#endif
