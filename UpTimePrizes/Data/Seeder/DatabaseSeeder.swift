import Foundation
import SwiftData

@MainActor
class DatabaseSeeder {
    static func seed(context: ModelContext) {
        // Seed Demo State
        let fetchDemo = FetchDescriptor<DemoStateEntity>()
        if try! context.fetchCount(fetchDemo) == 0 {
            let demoState = DemoStateEntity()
            context.insert(demoState)
        }
        
        // Seed Alarm
        let fetchAlarm = FetchDescriptor<AlarmEntity>()
        if try! context.fetchCount(fetchAlarm) == 0 {
            let alarm = AlarmEntity()
            context.insert(alarm)
        }
        
        // Seed Journeys
        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        if try! context.fetchCount(fetchJourneys) == 0 {
            let genesis = JourneyEntity(
                id: "demo",
                title: "The Genesis",
                descriptionText: "The original five-song experience.",
                type: "DEMO",
                totalDays: 9,
                isPurchaseOffered: false,
                isActive: true,
                purchaseState: "ACTIVE_IN_PROGRESS",
                completedDays: 0,
                currentDay: 1
            )
            context.insert(genesis)
            
            let overture = JourneyEntity(
                id: "library-a",
                title: "The Overture",
                descriptionText: "Forty-five original songs. One per morning.",
                type: "LIBRARY_A",
                totalDays: 45,
                isPurchaseOffered: true,
                isActive: false,
                purchaseState: "NOT_OWNED",
                completedDays: 0,
                currentDay: 1
            )
            context.insert(overture)
            
            let castPrelude = JourneyEntity(
                id: "signature",
                title: "The Cast Prelude",
                descriptionText: "Eight songs from our Signature Series.",
                type: "SIGNATURE",
                totalDays: 8,
                isPurchaseOffered: true,
                isActive: false,
                purchaseState: "NOT_OWNED",
                completedDays: 0,
                currentDay: 1
            )
            context.insert(castPrelude)
        }
        
        try? context.save()
    }
}
