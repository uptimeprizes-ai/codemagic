import SwiftUI
import SwiftData

// MARK: - HomeScreenView
//
// The clock (Android screen map §2, HomePage.kt): the date as an eyebrow,
// the analogue clock, NEXT ALARM with its repeat days, and a bottom plaque
// reading NOW and STREAK. Nothing to operate — deliberately.

struct HomeScreenView: View {

    @Environment(\.modelContext) private var context
    @Query private var alarms: [AlarmEntity]
    @Query private var mornings: [MorningRecordEntity]

    @State private var streak: Int = 0

    private var alarm: AlarmEntity? {
        guard let alarm = alarms.first, alarm.isEnabled else { return nil }
        return alarm
    }

    var body: some View {
        ZStack {
            PaperBackground()

            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                VStack(spacing: 0) {
                    Spacer().frame(height: 12)
                    eyebrow(timeline.date)

                    Spacer(minLength: 12)

                    AnalogClockFace(date: timeline.date)
                        .frame(maxWidth: 360)

                    Spacer().frame(height: 28)

                    status

                    Spacer(minLength: 12)

                    plaque(now: timeline.date)
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 24)
            }
        }
        .task(id: mornings.count) {
            streak = MorningLedger(context: context).streak()
        }
    }

    // MARK: - Eyebrow

    private func eyebrow(_ now: Date) -> some View {
        HStack {
            BrassScrew()
            Spacer()
            Text(HomeFormat.dateLabel(now))
                .font(.playfair(9, semibold: true))
                .tracking(9 * 0.32)
                .foregroundColor(BrassPaper.eyebrow)
                .shadow(color: Color.white.opacity(0.55), radius: 0.5, x: 0, y: 1)
            Spacer()
            BrassScrew()
        }
    }

    // MARK: - Next alarm

    private var status: some View {
        VStack(spacing: 6) {
            Text("NEXT ALARM")
                .font(.playfair(10, semibold: true))
                .tracking(10 * 0.34)
                .foregroundColor(BrassPaper.eyebrow)
                .shadow(color: Color.white.opacity(0.60), radius: 0.5, x: 0, y: 1.2)

            Text(alarm.map { HomeFormat.clock(hour: $0.hour, minute: $0.minute) } ?? "No alarm set")
                .font(.playfair(30, semibold: alarm != nil))
                .foregroundColor(alarm != nil ? BrassPaper.ink : BrassPaper.inkSoft)
                .shadow(color: Color.white.opacity(0.55), radius: 0.8, x: 0, y: 1.5)

            if let alarm, !alarm.repeatDays.isEmpty {
                Text(HomeFormat.repeatLine(alarm.repeatDays))
                    .font(.mono(10))
                    .tracking(10 * 0.18)
                    .foregroundColor(BrassPaper.inkSoft.opacity(0.7))
                    .shadow(color: Color.white.opacity(0.50), radius: 0.5, x: 0, y: 1)
            }
        }
    }

    // MARK: - NOW / STREAK plaque

    private func plaque(now: Date) -> some View {
        HStack {
            plaqueColumn("NOW", HomeFormat.nowLabel(now), alignment: .leading)
            Spacer()
            plaqueColumn("STREAK", streak > 0 ? "\(streak) DAYS" : "\u{2014}", alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(BrassPaper.plaqueFill)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrassPaper.plaqueBorder, lineWidth: 1))
        .shadow(color: BrassPaper.plaqueShadow.opacity(0.30), radius: 8, x: 0, y: 4)
    }

    private func plaqueColumn(_ eyebrow: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(eyebrow)
                .font(.playfair(9, semibold: true))
                .tracking(9 * 0.36)
                .foregroundColor(BrassPaper.brassHighlight.opacity(0.85))
            Text(value)
                .font(.mono(18, weight: .medium))
                .tracking(18 * 0.1)
                .foregroundColor(BrassPaper.screenGlow)
        }
    }
}

// MARK: - HomeFormat
//
// Home's strings, formatted as Android formats them. Pure, so tested.

enum HomeFormat {
    private static let dayNames = [1: "SUN", 2: "MON", 3: "TUE", 4: "WED", 5: "THU", 6: "FRI", 7: "SAT"]

    /// "WEDNESDAY, SEP 23"
    static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date).uppercased()
    }

    /// "7:30 AM" — no leading zero.
    static func clock(hour: Int, minute: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h):\(String(format: "%02d", minute)) \(hour < 12 ? "AM" : "PM")"
    }

    static func nowLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// "·  MON  WED  FRI  ·"
    static func repeatLine(_ days: [Int]) -> String {
        let label = days.sorted().compactMap { dayNames[$0] }.joined(separator: "  ")
        return "·  \(label)  ·"
    }
}
