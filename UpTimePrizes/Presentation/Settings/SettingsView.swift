import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var journeys: [JourneyEntity]
    @Query private var demoState: [DemoStateEntity]
    
    private var activeJourney: JourneyEntity? {
        journeys.first(where: { $0.isActive })
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active Journey Card
                    ActiveJourneyCard(journey: activeJourney)
                    
                    // Progress Card
                    if let state = demoState.first {
                        ProgressCard(demoState: state)
                    }
                    
                    // About Card
                    AboutCard()
                    
                    #if DEBUG
                    NavigationLink("Debug Tools") {
                        DebugView()
                    }
                    .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                    .foregroundColor(DesignTokens.brass)
                    #endif
                }
                .padding()
            }
            .background(DesignTokens.paper)
            .navigationTitle("Settings")
        }
    }
}

struct ActiveJourneyCard: View {
    let journey: JourneyEntity?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVE JOURNEY")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 12))
                .foregroundColor(DesignTokens.brass)
                .tracking(2)
            
            Text(journey?.title ?? "None")
                .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 20))
                .foregroundColor(DesignTokens.ink)
            
            if let journey = journey {
                Text("Day \(journey.currentDay) of \(journey.totalDays)")
                    .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                    .foregroundColor(DesignTokens.ink.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct ProgressCard: View {
    let demoState: DemoStateEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GENESIS PROGRESS")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 12))
                .foregroundColor(DesignTokens.brass)
                .tracking(2)
            
            Text("\(demoState.completedDays) of 9 mornings completed")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.ink)
            
            ProgressView(value: Double(demoState.completedDays), total: 9)
                .tint(DesignTokens.brass)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct AboutCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 12))
                .foregroundColor(DesignTokens.brass)
                .tracking(2)
            
            Text("UpTime Prizes")
                .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 16))
                .foregroundColor(DesignTokens.ink)
            
            Text("Version 1.0.0")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.ink.opacity(0.7))
            
            Link("Privacy Policy", destination: URL(string: "https://uptimeprizes.com/privacy")!)
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.brass)
            
            Link("Support", destination: URL(string: "https://uptimeprizes.com/support")!)
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.brass)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}
