import SwiftUI
import SwiftData

struct DebugView: View {
    @Query private var demoState: [DemoStateEntity]
    @Query private var journeys: [JourneyEntity]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            Section("Demo State") {
                if let state = demoState.first {
                    Text("Current Day: \(state.currentDay)")
                    Text("Completed Days: \(state.completedDays)")
                    Text("Purchase Offered: \(state.isPurchaseOffered ? "Yes" : "No")")
                    
                    Button("Pin Day 9") {
                        state.currentDay = 9
                        state.completedDays = 9
                        state.isPurchaseOffered = true
                        try? modelContext.save()
                    }
                    
                    Button("Reset to Day 1") {
                        state.currentDay = 1
                        state.completedDays = 0
                        state.isPurchaseOffered = false
                        try? modelContext.save()
                    }
                }
            }
            
            Section("Journeys") {
                ForEach(journeys, id: \.id) { journey in
                    VStack(alignment: .leading) {
                        Text(journey.title)
                            .font(.headline)
                        Text("State: \(journey.purchaseState)")
                        Text("Day \(journey.currentDay)/\(journey.totalDays) | Completed: \(journey.completedDays)")
                    }
                }
            }
        }
        .navigationTitle("Debug Tools")
    }
}
