import SwiftUI
import SwiftData

// MARK: - HomeScreenView

/// The main home screen shown when the app opens.
/// Features a dominant clock display, the next alarm time, and the active journey name.
/// Matches the Android home screen experience.
struct HomeScreenView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var alarms: [AlarmEntity]
    @Query private var demoStates: [DemoStateEntity]

    // MARK: - State

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    private var alarm: AlarmEntity? { alarms.first }
    private var activeJourney: JourneyEntity? { journeys.first(where: { $0.isActive }) }
    private var demoState: DemoStateEntity? { demoStates.first }

    private var alarmTimeString: String {
        guard let alarm = alarm, alarm.isEnabled else { return "No alarm set" }
        let h = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        let m = String(format: "%02d", alarm.minute)
        let period = alarm.hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(period)"
    }

    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: currentTime)
    }

    private var currentPeriodString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: currentTime)
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }

    private var journeyProgressText: String {
        guard let journey = activeJourney else { return "" }
        if journey.purchaseState == "UNLOCKED_FOR_PLAYBACK" {
            return "\(journey.title) — Unlocked"
        }
        return "\(journey.title) — Day \(journey.completedDays + 1) of \(journey.totalDays)"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("paper").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Date
                Text(currentDateString)
                    .font(.custom("PlayfairDisplay-Regular", size: 16))
                    .foregroundColor(Color("ink").opacity(0.5))
                    .tracking(1)

                Spacer().frame(height: 16)

                // Dominant clock
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currentTimeString)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 88))
                        .foregroundColor(Color("ink"))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(currentPeriodString)
                        .font(.custom("PlayfairDisplay-Regular", size: 28))
                        .foregroundColor(Color("ink").opacity(0.5))
                        .padding(.bottom, 12)
                }

                Spacer().frame(height: 32)

                // Alarm indicator
                HStack(spacing: 8) {
                    Image(systemName: alarm?.isEnabled == true ? "alarm.fill" : "alarm")
                        .font(.system(size: 16))
                        .foregroundColor(alarm?.isEnabled == true ? Color("brass") : Color("ink").opacity(0.3))

                    Text(alarmTimeString)
                        .font(.custom("PlayfairDisplay-Regular", size: 18))
                        .foregroundColor(alarm?.isEnabled == true ? Color("ink") : Color("ink").opacity(0.4))
                }

                Spacer().frame(height: 20)

                // Active journey
                if let journey = activeJourney {
                    Text(journeyProgressText)
                        .font(.custom("PlayfairDisplay-Regular", size: 13))
                        .foregroundColor(Color("ink").opacity(0.5))
                        .tracking(0.5)
                }

                Spacer()

                // Tagline
                Text("No buzz. No blare. Just melody.")
                    .font(.custom("PlayfairDisplay-Regular", size: 13))
                    .foregroundColor(Color("brass").opacity(0.7))
                    .tracking(1)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 32)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}

#Preview {
    HomeScreenView()
        .modelContainer(for: [JourneyEntity.self, AlarmEntity.self, DemoStateEntity.self, SongEntity.self], inMemory: true)
}
