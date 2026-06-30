import SwiftUI
import SwiftData

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var demoStates: [DemoStateEntity]

    // MARK: - Observed

    @ObservedObject var alarmEngine: AlarmEngine

    // MARK: - State

    @State private var showDebug: Bool = false

    // MARK: - Computed

    private var demoState: DemoStateEntity? { demoStates.first }
    private var activeJourney: JourneyEntity? { journeys.first(where: { $0.isActive }) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Active journey section
                Section("Active Journey") {
                    if let journey = activeJourney {
                        LabeledContent(journey.title, value: journey.purchaseState.replacingOccurrences(of: "_", with: " ").capitalized)
                        LabeledContent("Progress", value: "Day \(journey.completedDays) of \(journey.totalDays)")
                    } else {
                        Text("No active journey")
                            .foregroundColor(Color("ink").opacity(0.5))
                    }
                }

                // Genesis section
                Section("The Genesis") {
                    LabeledContent("Mornings completed", value: "\(demoState?.completedDays ?? 0) of 9")
                    LabeledContent("Discover unlocked", value: (demoState?.completedDays ?? 0) >= 9 ? "Yes" : "No")
                }

                // All journeys
                Section("All Journeys") {
                    ForEach(journeys, id: \.id) { journey in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(journey.title)
                                    .font(.custom("PlayfairDisplay-SemiBold", size: 14))
                                if journey.isActive {
                                    Text("Active")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color("brass").opacity(0.15))
                                        .foregroundColor(Color("brass"))
                                        .clipShape(Capsule())
                                }
                            }
                            Text("Day \(journey.completedDays)/\(journey.totalDays) · \(journey.purchaseState)")
                                .font(.caption)
                                .foregroundColor(Color("ink").opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Links
                Section("About") {
                    Link("Privacy Policy", destination: URL(string: "https://uptimeprizes.com/privacy")!)
                    Link("Support", destination: URL(string: "https://uptimeprizes.com/support")!)
                }

                // Debug (only in DEBUG builds)
                #if DEBUG
                Section("Developer") {
                    Button("Open Debug Tools") {
                        showDebug = true
                    }
                    .foregroundColor(Color("brass"))
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showDebug) {
            DebugView(alarmEngine: alarmEngine)
        }
    }
}
