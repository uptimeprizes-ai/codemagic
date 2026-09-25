import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit

// MARK: - AlarmKitScheduler (Option 2 — founder, 2026-09-23)
//
// On iOS 26+ the morning is rung by AlarmKit: a real system alarm that
// breaks through the silent switch and Focus, snoozes at the person's own
// gap, and — because an authorized AlarmKit alarm always sounds — makes
// "the morning counts because it sounded" an honest statement even when
// nobody answers. Devices below iOS 26 keep the notification path.
//
// Sound: the UpTime doorbell (founder, Option B): one signature sound, the
// same every morning and every snooze return, shipped exactly as delivered.

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

    /// Whether AlarmKit currently holds our morning alarm.
    static var isScheduled: Bool {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        return alarms.contains { $0.id == alarmUUID }
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

        // Replace, never stack: cancel any alarm already holding our id.
        try? AlarmManager.shared.cancel(id: alarmUUID)

        do {
            let configuration = AlarmManager.AlarmConfiguration(
                countdownDuration: nil,
                schedule: schedule,
                attributes: makeAttributes(),
                stopIntent: OpenMorningIntent(),
                sound: alarmSound
            )
            _ = try await AlarmManager.shared.schedule(id: alarmUUID, configuration: configuration)
        } catch {
            UpTimeLog.alarm.error("[ALARM] AlarmKit schedule threw: \(String(reflecting: error), privacy: .public)")
            throw error
        }
        UpTimeLog.alarm.notice("[ALARM] AlarmKit scheduled \(hour, privacy: .public):\(String(format: "%02d", minute), privacy: .public) alert-only, sound=\(doorbellFile, privacy: .public)")
    }

    static func cancel() {
        try? AlarmManager.shared.cancel(id: alarmUUID)
    }

    // MARK: - Snooze return (the doorbell after a snooze)
    //
    // While the phone is locked — or the person is in another app — only
    // the system alarm can make sound. A snooze return therefore rings as
    // its own one-off AlarmKit alarm, through the silent switch, and its
    // Dismiss opens the app at the stage the snooze sent forward. It has
    // its OWN id, so it can never replace or cancel the recurring morning.

    static let snoozeUUID = UUID(uuidString: "0B5E5EAD-0000-4000-8000-C0FFEE000002")!

    static func scheduleSnoozeReturn(after minutes: Int) async throws {
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        try? AlarmManager.shared.cancel(id: snoozeUUID)
        do {
            let configuration = AlarmManager.AlarmConfiguration(
                countdownDuration: nil,
                schedule: Alarm.Schedule.fixed(fireDate),
                attributes: makeAttributes(),
                stopIntent: OpenMorningIntent(),
                sound: alarmSound
            )
            _ = try await AlarmManager.shared.schedule(id: snoozeUUID, configuration: configuration)
        } catch {
            UpTimeLog.alarm.error("[ALARM] AlarmKit snooze return threw: \(String(reflecting: error), privacy: .public)")
            throw error
        }
        UpTimeLog.alarm.notice("[ALARM] AlarmKit snooze return scheduled in \(minutes, privacy: .public) min")
    }

    static func cancelSnoozeReturn() {
        try? AlarmManager.shared.cancel(id: snoozeUUID)
    }

    // MARK: - Shared configuration

    /// The doorbell's file name at the bundle root (≤30 s; AlarmKit's cap).
    static let doorbellFile = "door_bell_006.m4a"

    /// The doorbell when it is in the bundle; the system sound otherwise.
    private static var alarmSound: AlertConfiguration.AlertSound {
        if Bundle.main.url(forResource: "door_bell_006", withExtension: "m4a") != nil {
            return .named(doorbellFile)
        }
        UpTimeLog.alarm.error("[ALARM] doorbell missing from the bundle — using the system sound")
        return .default
    }

    /// Alert-only presentation (no countdown — see schedule's note). Every
    /// configuration pairs it with OpenMorningIntent, so Dismiss stops the
    /// ring AND opens the app into the morning.
    private static func makeAttributes() -> AlarmAttributes<UpTimeAlarmMetadata> {
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
        return AlarmAttributes<UpTimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color("brass")
        )
    }
}
#endif
