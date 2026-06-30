import SwiftUI
import SwiftData

// MARK: - DebugView (DEBUG builds only)

struct DebugView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var journeys: [JourneyEntity]
    @Query private var demoStates: [DemoStateEntity]
    @Query private var alarms: [AlarmEntity]

    // MARK: - Observed

    @ObservedObject var alarmEngine: AlarmEngine

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // DemoState
                Section("Demo State") {
                    if let demo = demoStates.first {
                        LabeledContent("completedDays", value: "\(demo.completedDays)")
                        LabeledContent("currentDay", value: "\(demo.currentDay)")
                        LabeledContent("isPurchaseOffered", value: "\(demo.isPurchaseOffered)")
                        LabeledContent("isActive", value: "\(demo.isActive)")
                    }
                }

                // Journey states
                Section("Journey States") {
                    ForEach(journeys, id: \.id) { journey in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(journey.title) (\(journey.id))")
                                .font(.caption.bold())
                            Text("state: \(journey.purchaseState)")
                                .font(.caption)
                            Text("days: \(journey.completedDays)/\(journey.totalDays) · currentDay: \(journey.currentDay)")
                                .font(.caption)
                            Text("isActive: \(journey.isActive)")
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Alarm state
                Section("Alarm") {
                    if let alarm = alarms.first {
                        LabeledContent("Time", value: String(format: "%02d:%02d", alarm.hour, alarm.minute))
                        LabeledContent("Enabled", value: "\(alarm.isEnabled)")
                        LabeledContent("Repeat days", value: alarm.repeatDays.map { "\($0)" }.joined(separator: ", "))
                    }
                }

                // Debug actions
                Section("Actions") {
                    Button("Pin Day 9 (Unlock Discover)") {
                        pinDay9()
                    }
                    .foregroundColor(.orange)

                    Button("Reset to Day 1") {
                        resetToDay1()
                    }
                    .foregroundColor(.red)

                    Button("Simulate Alarm Dismiss (Advance Day)") {
                        alarmEngine.handleAlarmDismissed()
                    }
                    .foregroundColor(.blue)

                    Button("Trigger Alarm UI Now") {
                        NotificationCenter.default.post(name: AlarmEngine.alarmFiredNotificationName, object: nil)
                    }
                    .foregroundColor(.purple)
                }
            }
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Actions

    private func pinDay9() {
        if let demo = demoStates.first {
            demo.completedDays = 9
            demo.currentDay = 5
            demo.isPurchaseOffered = true
        }
        if let genesis = journeys.first(where: { $0.id == "demo" }) {
            genesis.completedDays = 9
            genesis.currentDay = 5
        }
        try? context.save()
    }

    private func resetToDay1() {
        if let demo = demoStates.first {
            demo.completedDays = 0
            demo.currentDay = 1
            demo.isPurchaseOffered = false
            demo.isActive = true
        }
        for journey in journeys {
            journey.completedDays = 0
            journey.currentDay = 1
            journey.isActive = journey.id == "demo"
            if journey.type != "DEMO" {
                journey.purchaseState = "NOT_OWNED"
            } else {
                journey.purchaseState = "ACTIVE_IN_PROGRESS"
            }
        }
        try? context.save()
    }
}
