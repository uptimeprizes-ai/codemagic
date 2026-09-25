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
            UpTimeLog.alarm.error("[ALARM] notification permission error: \(error, privacy: .public)")
            return false
        }
    }

    // MARK: - Schedule

    /// Schedule the morning alarm. On iOS 26+ with authorization, AlarmKit
    /// rings it (a real alarm: through the silent switch, snooze at the
    /// person's gap); otherwise the notification path does. Never both.
    /// - Parameters:
    ///   - hour: Hour in 24h format
    ///   - minute: Minute
    ///   - repeatDays: Array of weekday integers (1 = Sunday … 7 = Saturday). Empty = daily.
    func scheduleAlarm(hour: Int, minute: Int, repeatDays: [Int]) {
        // Anchors the unattended-morning check: no morning before the alarm
        // existed in this form is ever judged (routine re-arming keeps it).
        AlarmRingLog.recordArmed(hour: hour, minute: minute, repeatDays: repeatDays)
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let snooze = snoozeMinutes
            Task { @MainActor in
                if await AlarmKitScheduler.requestAuthorization() {
                    do {
                        try await AlarmKitScheduler.schedule(
                            hour: hour, minute: minute,
                            repeatDays: repeatDays, snoozeMinutes: snooze
                        )
                        // AlarmKit owns the morning — clear the notification
                        // path so the two systems never both fire.
                        UNUserNotificationCenter.current()
                            .removePendingNotificationRequests(withIdentifiers: self.allAlarmIdentifiers())
                        return
                    } catch {
                        UpTimeLog.alarm.error("[ALARM] AlarmKit scheduling failed — using notifications: \(error, privacy: .public)")
                    }
                }
                self.scheduleNotificationAlarm(hour: hour, minute: minute, repeatDays: repeatDays)
            }
            return
        }
        #endif
        scheduleNotificationAlarm(hour: hour, minute: minute, repeatDays: repeatDays)
    }

    /// The pre-iOS-26 path: a calendar-triggered local notification.
    private func scheduleNotificationAlarm(hour: Int, minute: Int, repeatDays: [Int]) {
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
                    UpTimeLog.alarm.error("[ALARM] failed to schedule daily alarm: \(error, privacy: .public)")
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
                        UpTimeLog.alarm.error("[ALARM] failed to schedule weekday \(weekday): \(error, privacy: .public)")
                    }
                }
            }
        }
        UpTimeLog.alarm.notice("[ALARM] scheduled \(hour, privacy: .public):\(String(format: "%02d", minute), privacy: .public) repeatDays=\(repeatDays, privacy: .public)")
    }

    func cancelAlarm() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            AlarmKitScheduler.cancel()
            AlarmKitScheduler.cancelSnoozeReturn()
        }
        #endif
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

        // When AlarmKit owns the morning there are deliberately no pending
        // notifications; the alarm is healthy if AlarmKit holds it.
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), AlarmKitScheduler.isAuthorized, AlarmKitScheduler.isScheduled {
            return
        }
        #endif

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let alarmIds = Set(allAlarmIdentifiers())
        let hasScheduled = pending.contains { alarmIds.contains($0.identifier) }

        if !hasScheduled {
            UpTimeLog.alarm.notice("[ALARM] enabled but nothing pending — re-arming")
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
    /// The in-app session owns this morning from here, so it also marks the
    /// latest ring as answered for the unattended-morning check.
    func beginAlarmSession() {
        hasCountedThisSession = false
        isAlarmActive = true
        AlarmRingLog.recordAnswered()
    }

    enum UnattendedResult {
        case missed(sounded: Bool)
        case nothing
    }

    /// Ends an in-app session that nobody answered (the Option B stop).
    /// Founder ruling 2026-09-25: an unanswered alarm does not count - no
    /// journey progress, no streak - so nothing is recorded; the morning is
    /// only reported as missed.
    func endUnansweredSession() {
        isAlarmActive = false
        UpTimeLog.counting.notice("[MORNING] not counted — nobody answered")
    }

    /// At launch and on every return to the foreground: find the most recent
    /// AlarmKit morning that nobody answered (see UnattendedMorning) and
    /// report it, once. It is never counted (founder ruling 2026-09-25). Only
    /// AlarmKit mornings qualify, because only they can say whether the
    /// alarm actually sounded.
    func checkUnattendedMorning(now: Date = Date()) -> UnattendedResult {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), AlarmKitScheduler.isAuthorized else { return .nothing }
        guard let alarm = try? context.fetch(FetchDescriptor<AlarmEntity>()).first,
              alarm.isEnabled else { return .nothing }

        let occurrence = UnattendedMorning.mostRecentOccurrence(
            before: now, hour: alarm.hour, minute: alarm.minute, repeatDays: alarm.repeatDays
        )
        let ledger = MorningLedger(context: context)
        let recorded = occurrence.map { ledger.hasRecord(dayKey: MorningLedger.dayKey(for: $0)) } ?? false
        let verdict = UnattendedMorning.evaluate(
            now: now,
            occurrence: occurrence,
            armedSince: AlarmRingLog.armedSince,
            lastSnoozeReturnAt: AlarmRingLog.lastSnoozeReturnAt,
            lastAnsweredAt: AlarmRingLog.lastAnsweredAt,
            bootTime: AlarmRingLog.bootTime(),
            alreadyRecorded: recorded,
            alreadyEvaluated: occurrence.map(AlarmRingLog.wasEvaluated) ?? false
        )

        switch verdict {
        case .none:
            return .nothing
        case .didNotSound(let occurrence):
            AlarmRingLog.markEvaluated(occurrence)
            UpTimeLog.counting.notice("[MORNING] missed — the alarm did not sound (phone was off); not counted")
            return .missed(sounded: false)
        case .soundedUnanswered(let occurrence):
            AlarmRingLog.markEvaluated(occurrence)
            UpTimeLog.counting.notice("[MORNING] missed — the alarm sounded, nobody answered; not counted")
            return .missed(sounded: true)
        }
        #else
        return .nothing
        #endif
    }

    /// Everything the Prize screen needs about a counted morning.
    struct MorningOutcome {
        let journeyTitle: String
        let morningNumber: Int   // completedDays after counting
        let totalDays: Int
        let journeyComplete: Bool
        let reachedPrize: Bool
        let heldStreakOnly: Bool // Catalyst morning (later: Genesis fallback)
        let wasUnanswered: Bool  // the alarm ended itself — nobody answered
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
    func handleAlarmDismissed(audioSounded: Bool, stageAtDismiss: String, reachedPrize: Bool, wasUnanswered: Bool = false, date: Date = Date()) -> MorningOutcome? {
        defer { isAlarmActive = false }

        guard audioSounded else {
            UpTimeLog.counting.notice("[MORNING] not counted — audio never sounded")
            return nil
        }
        guard !hasCountedThisSession else {
            UpTimeLog.counting.notice("[MORNING] not counted — already recorded this session")
            return nil
        }

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
        guard counted else {
            UpTimeLog.counting.notice("[MORNING] not counted — this calendar day already has its morning")
            return nil
        }

        hasCountedThisSession = true
        UpTimeLog.counting.notice("[MORNING] counted journey=\(active.id, privacy: .public) morning=\(active.completedDays + (isCatalyst ? 0 : 1), privacy: .public)/\(active.totalDays, privacy: .public) stage=\(stageAtDismiss, privacy: .public) heldStreakOnly=\(isCatalyst, privacy: .public)")

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
            heldStreakOnly: isCatalyst,
            wasUnanswered: wasUnanswered
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
    /// inside the app, as a folder reference at Audio/genesis (the pipeline's
    /// approved iOS set). Every other journey's audio arrives by download.
    func subdirectory(for journeyId: String) -> String? {
        journeyId == "genesis" ? "Audio/genesis" : nil
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

    /// The snooze options the person can choose from (§2.5). Default 10.
    static let snoozeOptions = [5, 10, 15, 20, 30]
    static let defaultSnoozeMinutes = 10

    /// Snooze returns one stage further (§2.1): snooze in the Invite and the
    /// Nudge comes back; snooze in the Nudge and the Prize comes back.
    /// There is no Snooze in the Prize stage.
    static func stageAfterSnooze(_ stage: String) -> String {
        switch stage {
        case "invite": return "nudge"
        case "nudge": return "prize"
        default: return stage
        }
    }

    /// The person's chosen snooze gap, from the alarm row.
    var snoozeMinutes: Int {
        let alarm = try? context.fetch(FetchDescriptor<AlarmEntity>()).first
        return alarm?.snoozeMinutes ?? Self.defaultSnoozeMinutes
    }

    /// Snooze the alarm: stop audio, remember which stage comes back and for
    /// how long that memory is valid, and schedule the return at the
    /// person's own gap. On iOS 26+ with AlarmKit authorized, the return
    /// rings as its own lock-screen alarm (through the silent switch — a
    /// notification would be muted); otherwise a notification carries it.
    func snoozeAlarm(stageAtSnooze: String) {
        let minutes = snoozeMinutes

        // Persist the resume stage — consumed once by the next session, valid
        // only through the snooze window plus a grace period, so a stale
        // resume can never leak into the next morning.
        if let alarm = try? context.fetch(FetchDescriptor<AlarmEntity>()).first {
            alarm.resumeStage = Self.stageAfterSnooze(stageAtSnooze)
            alarm.resumeStageValidUntil = Date().addingTimeInterval(TimeInterval((minutes + 5) * 60))
            try? context.save()
        }
        UpTimeLog.alarm.notice("[ALARM] snoozed \(minutes, privacy: .public) min — \(Self.stageAfterSnooze(stageAtSnooze), privacy: .public) comes back")
        isAlarmActive = false
        // Note: snooze does NOT count a morning — only a dismissal can.

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), AlarmKitScheduler.isAuthorized {
            Task { @MainActor in
                do {
                    try await AlarmKitScheduler.scheduleSnoozeReturn(after: minutes)
                    AlarmRingLog.recordSnoozeReturn(at: Date().addingTimeInterval(TimeInterval(minutes * 60)))
                } catch {
                    UpTimeLog.alarm.error("[ALARM] snooze return via AlarmKit failed — using a notification")
                    self.scheduleSnoozeNotification(minutes: minutes)
                }
            }
            return
        }
        #endif
        scheduleSnoozeNotification(minutes: minutes)
    }

    /// The pre-iOS-26 (and fallback) snooze return: a one-off notification.
    private func scheduleSnoozeNotification(minutes: Int) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = Self.placeholderAlarmTitle
        content.body = Self.placeholderAlarmBody
        content.sound = UNNotificationSound.default
        content.userInfo = ["type": "alarm"]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )
        let snoozeId = "\(Self.alarmNotificationIdentifier).snooze"
        center.removePendingNotificationRequests(withIdentifiers: [snoozeId])
        let request = UNNotificationRequest(identifier: snoozeId, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                UpTimeLog.alarm.error("[ALARM] failed to schedule snooze: \(error, privacy: .public)")
            }
        }
    }

    /// The stage the next alarm session should start at: the snoozed-in stage
    /// if the resume is still valid, otherwise the Invite. Consumes the
    /// resume either way, and a fresh morning (starting at the Invite) also
    /// resets the one-per-alarm auto-snooze allowance.
    func consumeResumeStage() -> String {
        guard let alarm = try? context.fetch(FetchDescriptor<AlarmEntity>()).first else { return "invite" }
        let stage = Date() < alarm.resumeStageValidUntil ? alarm.resumeStage : "invite"
        alarm.resumeStage = "invite"
        alarm.resumeStageValidUntil = Date.distantPast
        if stage == "invite" {
            alarm.autoSnoozeUsed = false // a snooze return never resumes at the Invite
        }
        try? context.save()
        return stage
    }

    // MARK: - Option B ring limits

    var autoSnoozeUsed: Bool {
        (try? context.fetch(FetchDescriptor<AlarmEntity>()).first)?.autoSnoozeUsed ?? false
    }

    /// The app snoozing for the person: same path as their own snooze
    /// (§2.1), plus the persisted one-per-alarm mark.
    func autoSnooze(stageAtSnooze: String) {
        if let alarm = try? context.fetch(FetchDescriptor<AlarmEntity>()).first {
            alarm.autoSnoozeUsed = true
            try? context.save()
        }
        UpTimeLog.alarm.notice("[ALARM] ring limit — auto-snoozing once")
        snoozeAlarm(stageAtSnooze: stageAtSnooze)
    }
}
