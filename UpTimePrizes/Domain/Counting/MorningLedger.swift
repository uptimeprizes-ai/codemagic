import Foundation
import SwiftData

// MARK: - MorningLedger
//
// The single place that decides what counts as a morning (handoff §2.4):
// - A morning counts only if audio actually sounded.
// - One morning per calendar day; extra alarms never count twice.
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

    /// Records a counted morning. Returns false (and records nothing) if this
    /// calendar day already has a morning — never two on one day.
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
        guard !hasRecord(dayKey: key) else { return false }
        context.insert(MorningRecordEntity(
            dayKey: key,
            journeyId: journeyId,
            stageAtDismiss: stageAtDismiss,
            reachedPrize: reachedPrize,
            heldStreakOnly: heldStreakOnly,
            advancedJourney: advancedJourney,
            recordedAt: date
        ))
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
