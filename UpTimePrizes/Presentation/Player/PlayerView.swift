import SwiftUI
import SwiftData

struct PlayerView: View {
    @Query private var journeys: [JourneyEntity]
    @Query private var demoState: [DemoStateEntity]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Alarm Card
                    AlarmCardView()
                    
                    // Library Sections
                    ForEach(unlockedJourneys, id: \.id) { journey in
                        LibrarySectionView(journey: journey)
                    }
                }
                .padding()
            }
            .background(DesignTokens.paper)
            .navigationTitle("UpTime Prizes")
        }
    }
    
    private var unlockedJourneys: [JourneyEntity] {
        journeys.filter { $0.purchaseState == "UNLOCKED_FOR_PLAYBACK" }
    }
}

struct AlarmCardView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("YOUR MORNING EXPERIENCE")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 12))
                .foregroundColor(DesignTokens.brass)
                .tracking(2)
            
            Text("7:00 AM")
                .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 48))
                .foregroundColor(DesignTokens.ink)
            
            Text("Set your alarm to begin")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct LibrarySectionView: View {
    let journey: JourneyEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(journey.title.uppercased())
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 12))
                .foregroundColor(DesignTokens.brass)
                .tracking(2)
            
            Text("\(journey.totalDays) songs unlocked")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.4))
        )
    }
}
