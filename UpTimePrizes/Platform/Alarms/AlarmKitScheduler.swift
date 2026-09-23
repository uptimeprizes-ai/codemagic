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
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            let state = try? await AlarmManager.shared.requestAuthorization()
            return state == .authorized
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

    /// Schedule (or replace) the morning alarm. The snooze gap is the
    /// person's own setting — AlarmKit's countdown postAlert IS the snooze.
    static func schedule(hour: Int, minute: Int, repeatDays: [Int], snoozeMinutes: Int) async throws {
        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdays(from: repeatDays))
        let schedule = Alarm.Schedule.relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))

        // "Dismiss" and "Snooze" are the specification's own vocabulary; the
        // alert title is the marked placeholder until the curator rules.
        let stopButton = AlarmButton(
            text: "Dismiss",
            textColor: .white,
            systemImageName: "stop.circle"
        )
        let snoozeButton = AlarmButton(
            text: "Snooze",
            textColor: .white,
            systemImageName: "clock"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: CuratorCopy.placeholderAlarmNotificationTitle),
            stopButton: stopButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .countdown
        )
        let attributes = AlarmAttributes<UpTimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color("brass")
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(snoozeMinutes * 60)
            ),
            schedule: schedule,
            attributes: attributes
        )

        _ = try await AlarmManager.shared.schedule(id: alarmUUID, configuration: configuration)
        UpTimeLog.alarm.notice("[ALARM] AlarmKit scheduled \(hour, privacy: .public):\(String(format: "%02d", minute), privacy: .public) snooze=\(snoozeMinutes, privacy: .public)m")
    }

    static func cancel() {
        try? AlarmManager.shared.cancel(id: alarmUUID)
    }
}
#endif
