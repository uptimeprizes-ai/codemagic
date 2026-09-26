import Foundation

// MARK: - UnattendedMorning
//
// On iOS no app code runs while an AlarmKit alarm rings. If nobody answers,
// the app learns about that morning only when it next runs. This decides,
// at that point, what to REPORT. Nothing here ever counts a morning:
// founder ruling 2026-09-25 — an unanswered alarm does not count in any
// form, no journey progress and no streak: no engagement, no credit.
//
//   - It rang and nobody answered → reported as missed (it sounded).
//   - The phone was off when it was due (booted after the ring) → reported
//     as missed (it did not sound).
//   - Someone answered the latest ring, or the morning is already recorded,
//     or the ring may still be going → nothing to report.
//
// "The latest ring" is the scheduled occurrence, or a snooze return that
// followed it — an answered first ring whose snooze came back unanswered is
// still a morning that played without anyone.
//
// Pure: every input is passed in, so every rule is unit-tested.

enum UnattendedMorning {

    /// A ring is over — and safe to judge — once this long has passed.
    /// Matches the Option B backstop.
    static let ringWindow: TimeInterval = RingDecision.prizeBackstopSeconds

    /// Only the most recent morning is judged; anything older is history.
    static let lookback: TimeInterval = 20 * 60 * 60

    enum Verdict: Equatable {
        case none
        case soundedUnanswered(occurrence: Date)
        case didNotSound(occurrence: Date)
    }

    /// The most recent time the alarm was due at or before `now`.
    /// repeatDays uses 1 = Sunday … 7 = Saturday; empty means every day.
    static func mostRecentOccurrence(
        before now: Date, hour: Int, minute: Int, repeatDays: [Int],
        calendar: Calendar = .current
    ) -> Date? {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  candidate <= now else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if repeatDays.isEmpty || repeatDays.contains(weekday) {
                return candidate
            }
        }
        return nil
    }

    /// Founder ruling 2026-09-26: a Dismiss more than 30 minutes after the
    /// ring began is not an answer. iOS leaves the alarm on screen after the
    /// sound stops (about 15 minutes), so without this rule a tap an hour
    /// later would start — and count — a morning nobody answered.
    static let answerWindow: TimeInterval = 30 * 60

    /// Whether a Dismiss at `now` comes too late to answer the ring. The ring
    /// is the scheduled occurrence, or a snooze return that followed it.
    static func isLateAnswer(now: Date, occurrence: Date?, lastSnoozeReturnAt: Date?) -> Bool {
        guard let occurrence else { return false }
        var latestRing = occurrence
        if let snooze = lastSnoozeReturnAt, snooze >= occurrence, snooze <= now {
            latestRing = snooze
        }
        return now.timeIntervalSince(latestRing) > answerWindow
    }

    static func evaluate(
        now: Date,
        occurrence: Date?,
        armedSince: Date?,
        lastSnoozeReturnAt: Date?,
        lastAnsweredAt: Date?,
        bootTime: Date?,
        alreadyRecorded: Bool,
        alreadyEvaluated: Bool
    ) -> Verdict {
        guard let occurrence else { return .none }
        // Never judge a morning from before this alarm existed in its current form.
        guard let armedSince, occurrence > armedSince else { return .none }
        guard now.timeIntervalSince(occurrence) <= lookback else { return .none }
        guard !alreadyEvaluated, !alreadyRecorded else { return .none }

        // The latest ring: the occurrence, or a snooze return that followed it.
        var latestRing = occurrence
        if let snooze = lastSnoozeReturnAt, snooze >= occurrence {
            latestRing = snooze
        }

        // The ring may still be going; judge only once it is over.
        guard now.timeIntervalSince(latestRing) >= ringWindow else { return .none }

        // Someone answered the latest ring — the in-app session owns it.
        if let answered = lastAnsweredAt, answered >= latestRing { return .none }

        // Phone off when the ring was due: it cannot have sounded.
        if let bootTime, bootTime > latestRing {
            return .didNotSound(occurrence: occurrence)
        }
        return .soundedUnanswered(occurrence: occurrence)
    }
}

// MARK: - AlarmRingLog
//
// The few facts the verdict needs, persisted across launches.

enum AlarmRingLog {
    private static let answeredKey = "com.uptimeprizes.ring.lastAnsweredAt"
    private static let snoozeReturnKey = "com.uptimeprizes.ring.lastSnoozeReturnAt"
    private static let armedSinceKey = "com.uptimeprizes.ring.armedSince"
    private static let armedConfigKey = "com.uptimeprizes.ring.armedConfig"
    private static let evaluatedKey = "com.uptimeprizes.ring.lastEvaluatedOccurrence"
    private static let armedHourKey = "com.uptimeprizes.ring.armedHour"
    private static let armedMinuteKey = "com.uptimeprizes.ring.armedMinute"
    private static let armedDaysKey = "com.uptimeprizes.ring.armedDays"

    static func recordAnswered(_ date: Date = Date()) { writeDate(date, answeredKey) }
    static var lastAnsweredAt: Date? { readDate(answeredKey) }

    static func recordSnoozeReturn(at date: Date) { writeDate(date, snoozeReturnKey) }
    static var lastSnoozeReturnAt: Date? { readDate(snoozeReturnKey) }

    /// Called whenever the alarm is (re-)scheduled. armedSince moves only when
    /// the alarm's time or days actually change — routine re-arming on launch
    /// must not hide a morning that already rang.
    static func recordArmed(hour: Int, minute: Int, repeatDays: [Int], now: Date = Date()) {
        UserDefaults.standard.set(hour, forKey: armedHourKey)
        UserDefaults.standard.set(minute, forKey: armedMinuteKey)
        UserDefaults.standard.set(repeatDays, forKey: armedDaysKey)
        let config = "\(hour):\(minute):\(repeatDays.sorted())"
        if UserDefaults.standard.string(forKey: armedConfigKey) != config || readDate(armedSinceKey) == nil {
            UserDefaults.standard.set(config, forKey: armedConfigKey)
            writeDate(now, armedSinceKey)
        }
    }
    static var armedSince: Date? { readDate(armedSinceKey) }

    /// The most recent time the armed alarm was due, for code that cannot
    /// reach the database (the lock-screen Dismiss).
    static func mostRecentOccurrence(before now: Date = Date()) -> Date? {
        guard UserDefaults.standard.object(forKey: armedHourKey) != nil else { return nil }
        return UnattendedMorning.mostRecentOccurrence(
            before: now,
            hour: UserDefaults.standard.integer(forKey: armedHourKey),
            minute: UserDefaults.standard.integer(forKey: armedMinuteKey),
            repeatDays: UserDefaults.standard.array(forKey: armedDaysKey) as? [Int] ?? []
        )
    }

    static func markEvaluated(_ occurrence: Date) { writeDate(occurrence, evaluatedKey) }
    static func wasEvaluated(_ occurrence: Date) -> Bool { readDate(evaluatedKey) == occurrence }

    /// When the device last booted. A ring due before the boot could not sound.
    static func bootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0, tv.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
    }

    private static func writeDate(_ date: Date, _ key: String) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }
    private static func readDate(_ key: String) -> Date? {
        let t = UserDefaults.standard.double(forKey: key)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
}
