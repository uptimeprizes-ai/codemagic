import Foundation
import AppIntents

#if canImport(AlarmKit)
import AlarmKit

// MARK: - OpenMorningIntent
//
// Runs when the person taps Dismiss on the AlarmKit lock-screen alarm. It
// stops the ring and starts the morning's song at once — on the lock
// screen, without unlocking (build 33 experiment, founder "option one").
// The app shows the running stage when opened; the morning counts, and the
// Prize screen appears, from there.
//
// The start request is persisted as well as posted: when the tap cold-
// launches the app, the post can land before the UI is listening, so the
// app also consumes the persisted request once it is ready. A request is
// honoured only while fresh, so a stale tap can never start a later morning.

@available(iOS 26.0, *)
struct OpenMorningIntent: LiveActivityIntent, AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Start the morning"
    static var isDiscoverable: Bool = false
    // Build 38 (founder, 2026-09-27): start the song at once in the
    // background, then bring the app forward — iOS asks for Touch ID and
    // the person lands on the alarm screen with the song already playing.
    // If they never unlock, the song simply keeps playing on the lock screen.
    static var supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    init() {}

    func perform() async throws -> some IntentResult {
        guard await LockScreenAnswer.answer(how: "AlarmKit dismissed") else { return .result() }
        do {
            try await continueInForeground(nil, alwaysConfirm: false)
            await MainActor.run {
                UpTimeLog.alarm.notice("[ALARM] lock screen: app brought forward after the song started")
            }
        } catch {
            await MainActor.run {
                UpTimeLog.alarm.notice("[ALARM] lock screen: app not brought forward (\(error, privacy: .public)) — the song plays on")
            }
        }
        return .result()
    }
}

// MARK: - LockScreenAnswer
//
// Answering the doorbell, however it happens: its button (the intent above),
// or opening the app while it is still ringing — the alarm's panel opens the
// app without running the button's code (founder's phone, 2026-09-27: the
// morning went unrecorded). Both paths answer the same way.

@available(iOS 26.0, *)
enum LockScreenAnswer {

    /// Whether our morning alarm or a snooze return is ringing right now.
    static var isRinging: Bool {
        let ours: Set<UUID> = [AlarmKitScheduler.alarmUUID, AlarmKitScheduler.snoozeUUID]
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        return alarms.contains { ours.contains($0.id) && $0.state == .alerting }
    }

    /// Returns true when the morning was answered (the song started); false
    /// when the answer came too late to count.
    @discardableResult
    static func answer(how: String) async -> Bool {
        // Either the morning alarm or a snooze return may be the one
        // ringing; stopping the other is a harmless no-op.
        try? AlarmManager.shared.stop(id: AlarmKitScheduler.alarmUUID)
        try? AlarmManager.shared.stop(id: AlarmKitScheduler.snoozeUUID)

        // Founder ruling 2026-09-26: more than 30 minutes after the ring,
        // Dismiss only clears the alarm. Nothing starts, nothing counts; the
        // app reports the morning missed when it opens.
        let now = Date()
        let occurrence = AlarmRingLog.mostRecentOccurrence(before: now)
        let snoozeReturn = AlarmRingLog.lastSnoozeReturnAt
        // Rule 4: the inputs to the late rule, logged every time, so a
        // morning that goes wrong can be read back afterwards.
        await MainActor.run {
            UpTimeLog.alarm.notice("[ALARM] \(how, privacy: .public): answered at \(now.formatted(date: .omitted, time: .standard), privacy: .public), alarm due \(occurrence?.formatted(date: .omitted, time: .standard) ?? "unknown", privacy: .public), last snooze return \(snoozeReturn?.formatted(date: .abbreviated, time: .standard) ?? "none", privacy: .public)")
        }
        if UnattendedMorning.isLateAnswer(
            now: now,
            occurrence: occurrence,
            lastSnoozeReturnAt: snoozeReturn
        ) {
            await MainActor.run {
                UpTimeLog.alarm.notice("[ALARM] \(how, privacy: .public) more than 30 min after the ring — not an answer, not counted")
            }
            return false
        }

        AlarmRingLog.recordAnswered()
        PendingMorningStart.record()
        await MainActor.run {
            UpTimeLog.alarm.notice("[ALARM] \(how, privacy: .public) — starting the morning on the lock screen")
            MorningStarter.startFromLockScreen()
            NotificationCenter.default.post(name: AlarmEngine.alarmFiredNotificationName, object: nil)
        }
        return true
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
