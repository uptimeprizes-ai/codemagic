import Foundation
import SwiftData

// MARK: - ProgressBackup
//
// Founder ruling 2026-09-28: progress must survive a damaged or replaced
// phone — "they should not have to start over again once they have
// completed their time." (App Builder catch-up handoff, 30 Sept, §4.)
//
// A few kilobytes of progress, kept in Application Support/UpTimeProgress/,
// which the iPhone's backup includes (the database itself stays excluded:
// restoring song rows would bring back stale audio regions). A phone
// restored from that backup, or set up from it, gets its mornings back.
//
// What it never does: grant ownership. A paid journey's progress is applied
// only once the App Store itself confirms the purchase (StoreKitManager);
// until then it is carried forward, untouched, in the record.
//
// Not covered: deleting the app and reinstalling it — iOS discards an app's
// data on deletion and never restores it from backup on reinstall. That needs
// iCloud key-value storage, an Apple account capability (after the account
// migration).

struct ProgressSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = ProgressSnapshot.currentVersion
    var savedAt: Date
    var journeys: [JourneyProgress]
    var activeJourneyId: String
    var demo: DemoProgress
    var mornings: [MorningMark]
    var alarm: AlarmSettings?
    var starredSongIds: [String]
    var welcomeSeen: Bool
    var dayNineSeen: Bool

    struct JourneyProgress: Codable, Equatable {
        var id: String
        var completedDays: Int
        var currentDay: Int
    }

    struct DemoProgress: Codable, Equatable {
        var currentDay: Int
        var completedDays: Int
        var isPurchaseOffered: Bool
    }

    struct MorningMark: Codable, Equatable {
        var dayKey: String
        var journeyId: String
        var stageAtDismiss: String
        var reachedPrize: Bool
        var heldStreakOnly: Bool
        var advancedJourney: Bool
        var recordedAt: Date
    }

    struct AlarmSettings: Codable, Equatable {
        var hour: Int
        var minute: Int
        var isEnabled: Bool
        var repeatDays: [Int]
        var snoozeMinutes: Int
    }
}

@MainActor
enum ProgressBackup {

    static let welcomeSeenKey = "com.uptimeprizes.welcomeSeen"
    static let dayNineSeenKey = "com.uptimeprizes.dayNineSeen"
    /// Mornings kept for the streak and the one-per-day rule.
    static let morningsKept = 120

    static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("UpTimeProgress", isDirectory: true)
            .appendingPathComponent("progress.json")
    }

    // MARK: - Snapshot

    /// What this phone holds now, merged with the previous record: progress
    /// for a paid journey this phone does not (yet) own is carried forward,
    /// so a restore waiting on the App Store can never be overwritten.
    static func snapshot(context: ModelContext, previous: ProgressSnapshot?, now: Date = Date()) -> ProgressSnapshot {
        let journeys = (try? context.fetch(FetchDescriptor<JourneyEntity>())) ?? []
        let ownedOrGenesis = journeys.filter { $0.id == "genesis" || $0.purchaseState != "NOT_OWNED" }
        var progress = ownedOrGenesis
            .filter { $0.completedDays > 0 || $0.currentDay > 1 }
            .map { ProgressSnapshot.JourneyProgress(id: $0.id, completedDays: $0.completedDays, currentDay: $0.currentDay) }
        let notOwnedHere = Set(journeys.filter { $0.id != "genesis" && $0.purchaseState == "NOT_OWNED" }.map(\.id))
        for carried in previous?.journeys ?? [] where notOwnedHere.contains(carried.id) {
            progress.append(carried)
        }

        let demo = (try? context.fetch(FetchDescriptor<DemoStateEntity>()))?.first
        let records = ((try? context.fetch(FetchDescriptor<MorningRecordEntity>())) ?? [])
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(morningsKept)
        let alarm = (try? context.fetch(FetchDescriptor<AlarmEntity>()))?.first
        let starred = (try? context.fetch(FetchDescriptor<StarredSongEntity>())) ?? []
        let active = journeys.first(where: { $0.isActive })?.id

        return ProgressSnapshot(
            savedAt: now,
            journeys: progress.sorted { $0.id < $1.id },
            activeJourneyId: active ?? previous?.activeJourneyId ?? "genesis",
            demo: ProgressSnapshot.DemoProgress(
                currentDay: demo?.currentDay ?? 1,
                completedDays: demo?.completedDays ?? 0,
                isPurchaseOffered: demo?.isPurchaseOffered ?? false
            ),
            mornings: records.map {
                ProgressSnapshot.MorningMark(
                    dayKey: $0.dayKey, journeyId: $0.journeyId, stageAtDismiss: $0.stageAtDismiss,
                    reachedPrize: $0.reachedPrize, heldStreakOnly: $0.heldStreakOnly,
                    advancedJourney: $0.advancedJourney, recordedAt: $0.recordedAt
                )
            },
            alarm: alarm.map {
                ProgressSnapshot.AlarmSettings(
                    hour: $0.hour, minute: $0.minute, isEnabled: $0.isEnabled,
                    repeatDays: $0.repeatDays, snoozeMinutes: $0.snoozeMinutes
                )
            },
            starredSongIds: starred.map(\.songId).sorted(),
            welcomeSeen: UserDefaults.standard.bool(forKey: welcomeSeenKey),
            dayNineSeen: UserDefaults.standard.bool(forKey: dayNineSeenKey)
        )
    }

    // MARK: - Save / load

    static func save(context: ModelContext, reason: String) {
        guard let url = fileURL else { return }
        let record = snapshot(context: context, previous: load())
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(record)
            try data.write(to: url, options: .atomic)
            let excluded = (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) ?? nil
            UpTimeLog.seed.notice("[BACKUP] saved (\(reason, privacy: .public)): \(data.count, privacy: .public) bytes, \(record.journeys.count, privacy: .public) journey(s) with progress, \(record.mornings.count, privacy: .public) morning(s), in backup=\(excluded == true ? "NO" : "yes", privacy: .public)")
        } catch {
            UpTimeLog.seed.error("[BACKUP] save failed (\(reason, privacy: .public)): \(error, privacy: .public)")
        }
    }

    static func load() -> ProgressSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProgressSnapshot.self, from: data)
    }

    // MARK: - Restore

    /// A store with nothing in it yet: no morning ever counted here.
    static func isFreshStore(context: ModelContext) -> Bool {
        let mornings = (try? context.fetchCount(FetchDescriptor<MorningRecordEntity>())) ?? 0
        let demo = (try? context.fetch(FetchDescriptor<DemoStateEntity>()))?.first
        return mornings == 0 && (demo?.completedDays ?? 0) == 0
    }

    /// At launch, after seeding: if this phone's store is fresh and a record
    /// exists (a restored or new phone), bring the progress back. Never
    /// touches ownership; never runs over a store that has progress.
    static func restoreIfFresh(context: ModelContext) {
        guard let snapshot = load() else {
            UpTimeLog.seed.notice("[BACKUP] no progress record on this phone")
            return
        }
        guard isFreshStore(context: context) else {
            UpTimeLog.seed.notice("[BACKUP] store already has progress — record not applied")
            return
        }
        apply(snapshot, to: context)
        try? context.save()
        UpTimeLog.seed.notice("[BACKUP] restored from \(snapshot.savedAt.formatted(date: .abbreviated, time: .shortened), privacy: .public): Genesis \(snapshot.demo.completedDays, privacy: .public)/9, \(snapshot.mornings.count, privacy: .public) morning(s); paid journeys wait for the App Store")
    }

    /// Applies everything except paid ownership. Paid journeys' progress is
    /// left in the record for `applyConfirmedOwnership` (exposed for tests).
    static func apply(_ snapshot: ProgressSnapshot, to context: ModelContext) {
        let journeys = (try? context.fetch(FetchDescriptor<JourneyEntity>())) ?? []

        if let genesis = journeys.first(where: { $0.id == "genesis" }),
           let saved = snapshot.journeys.first(where: { $0.id == "genesis" }) {
            genesis.completedDays = saved.completedDays
            genesis.currentDay = saved.currentDay
            if saved.completedDays >= genesis.totalDays {
                genesis.purchaseState = "UNLOCKED_FOR_PLAYBACK"
            }
        }
        if let demo = (try? context.fetch(FetchDescriptor<DemoStateEntity>()))?.first {
            demo.currentDay = snapshot.demo.currentDay
            demo.completedDays = snapshot.demo.completedDays
            demo.isPurchaseOffered = snapshot.demo.isPurchaseOffered
        }
        for mark in snapshot.mornings {
            context.insert(MorningRecordEntity(
                dayKey: mark.dayKey, journeyId: mark.journeyId, stageAtDismiss: mark.stageAtDismiss,
                reachedPrize: mark.reachedPrize, heldStreakOnly: mark.heldStreakOnly,
                advancedJourney: mark.advancedJourney, recordedAt: mark.recordedAt
            ))
        }
        if let saved = snapshot.alarm, let alarm = (try? context.fetch(FetchDescriptor<AlarmEntity>()))?.first {
            alarm.hour = saved.hour
            alarm.minute = saved.minute
            alarm.isEnabled = saved.isEnabled
            alarm.repeatDays = saved.repeatDays
            alarm.snoozeMinutes = saved.snoozeMinutes
        }
        for songId in snapshot.starredSongIds {
            context.insert(StarredSongEntity(songId: songId))
        }
        UserDefaults.standard.set(snapshot.welcomeSeen, forKey: welcomeSeenKey)
        UserDefaults.standard.set(snapshot.dayNineSeen, forKey: dayNineSeenKey)
    }

    /// Called only after the App Store has confirmed this journey is owned:
    /// brings back its mornings, and makes it active again if it was.
    /// Unlock follows mornings completed, never ownership alone.
    @discardableResult
    static func applyConfirmedOwnership(of journey: JourneyEntity, among journeys: [JourneyEntity], snapshot: ProgressSnapshot?) -> Bool {
        guard let snapshot,
              journey.completedDays == 0,
              let saved = snapshot.journeys.first(where: { $0.id == journey.id }),
              saved.completedDays > 0 || saved.currentDay > 1 else { return false }
        journey.completedDays = saved.completedDays
        journey.currentDay = saved.currentDay
        if journey.id != "catalyst" {
            journey.purchaseState = saved.completedDays >= journey.totalDays ? "UNLOCKED_FOR_PLAYBACK" : "ACTIVE_IN_PROGRESS"
        }
        if snapshot.activeJourneyId == journey.id {
            for other in journeys { other.isActive = other.id == journey.id }
        }
        UpTimeLog.seed.notice("[BACKUP] \(journey.id, privacy: .public): \(saved.completedDays, privacy: .public) morning(s) restored after the App Store confirmed ownership")
        return true
    }
}
