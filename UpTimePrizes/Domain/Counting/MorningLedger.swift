import Foundation
import SwiftData

// MARK: - MorningLedger
//
// The single place that decides what counts as a morning (handoff §2.4):
// - A morning counts only if audio actually sounded.
// - One morning per JOURNEY per calendar day (founder ruling, 11 Oct 2026):
//   extra alarms never count a journey twice, but two different journeys
//   may each count on the same day. The streak counts the day once.
// - A Catalyst morning holds the streak rather than extending or breaking it.
// - The streak is consecutive counted mornings, shows 0 the moment it is
//   broken (a live run means the last counted day was today or yesterday),
//   and has no lifetime total.

@MainActor
struct MorningLedger {

    let context: ModelContext

    // MARK: - Day keys (device-local calendar)

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Recording

    func hasRecord(dayKey: String) -> Bool {
        var fetch = FetchDescriptor<MorningRecordEntity>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        fetch.fetchLimit = 1
        return ((try? context.fetchCount(fetch)) ?? 0) > 0
    }

    /// Whether this journey already counted a morning on this day. Mornings
    /// counted before the per-journey record existed live only in the day's
    /// MorningRecordEntity, so both are read.
    func hasJourneyMorning(dayKey: String, journeyId: String, advancedOnly: Bool = false) -> Bool {
        let mineAny = #Predicate<JourneyMorningEntity> {
            $0.dayKey == dayKey && $0.journeyId == journeyId
        }
        let mineAdvanced = #Predicate<JourneyMorningEntity> {
            $0.dayKey == dayKey && $0.journeyId == journeyId && $0.advancedJourney == true
        }
        var mine = FetchDescriptor<JourneyMorningEntity>(predicate: advancedOnly ? mineAdvanced : mineAny)
        mine.fetchLimit = 1
        if ((try? context.fetchCount(mine)) ?? 0) > 0 { return true }

        let dayAny = #Predicate<MorningRecordEntity> {
            $0.dayKey == dayKey && $0.journeyId == journeyId
        }
        let dayAdvanced = #Predicate<MorningRecordEntity> {
            $0.dayKey == dayKey && $0.journeyId == journeyId && $0.advancedJourney == true
        }
        var day = FetchDescriptor<MorningRecordEntity>(predicate: advancedOnly ? dayAdvanced : dayAny)
        day.fetchLimit = 1
        return ((try? context.fetchCount(day)) ?? 0) > 0
    }

    private func dayRecord(dayKey: String) -> MorningRecordEntity? {
        var fetch = FetchDescriptor<MorningRecordEntity>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        fetch.fetchLimit = 1
        return try? context.fetch(fetch).first
    }

    /// Records a counted morning. Returns false (and records nothing) if this
    /// JOURNEY already counted today. A second journey on the same day counts
    /// for its journey; the day's streak record is written once, and a day
    /// first held by a Catalyst morning becomes a full day.
    @discardableResult
    func record(
        date: Date = Date(),
        journeyId: String,
        stageAtDismiss: String,
        reachedPrize: Bool,
        heldStreakOnly: Bool,
        advancedJourney: Bool
    ) -> Bool {
        let key = Self.dayKey(for: date)
        guard !hasJourneyMorning(dayKey: key, journeyId: journeyId) else { return false }
        context.insert(JourneyMorningEntity(
            dayKey: key, journeyId: journeyId, advancedJourney: advancedJourney, recordedAt: date
        ))
        if let day = dayRecord(dayKey: key) {
            if day.heldStreakOnly && !heldStreakOnly { day.heldStreakOnly = false }
        } else {
            context.insert(MorningRecordEntity(
                dayKey: key,
                journeyId: journeyId,
                stageAtDismiss: stageAtDismiss,
                reachedPrize: reachedPrize,
                heldStreakOnly: heldStreakOnly,
                advancedJourney: advancedJourney,
                recordedAt: date
            ))
        }
        try? context.save()
        return true
    }

    // MARK: - Streak

    /// Consecutive counted mornings ending today or yesterday; otherwise 0.
    /// Catalyst (and later fallback) mornings keep the run alive without
    /// adding to it.
    func streak(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        let records = (try? context.fetch(FetchDescriptor<MorningRecordEntity>())) ?? []
        guard !records.isEmpty else { return 0 }
        let byKey = Dictionary(uniqueKeysWithValues: records.map { ($0.dayKey, $0) })

        // The run is live only if the last counted day is today or yesterday.
        var cursor = date
        if byKey[Self.dayKey(for: cursor, calendar: calendar)] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  byKey[Self.dayKey(for: yesterday, calendar: calendar)] != nil else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while let record = byKey[Self.dayKey(for: cursor, calendar: calendar)] {
            if !record.heldStreakOnly { count += 1 }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    // MARK: - Review prompt inputs (§2.6)

    /// Every record is a sounded morning by construction.
    func soundedMorningsCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<MorningRecordEntity>())) ?? 0
    }

    func lastCountedDayIsTodayOrYesterday(asOf date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = Self.dayKey(for: date, calendar: calendar)
        guard let y = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        let yesterday = Self.dayKey(for: y, calendar: calendar)
        return hasRecord(dayKey: today) || hasRecord(dayKey: yesterday)
    }
}
