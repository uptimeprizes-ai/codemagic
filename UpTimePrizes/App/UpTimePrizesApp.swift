import SwiftUI
import SwiftData

@main
struct UpTimePrizesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JourneyEntity.self,
            SongEntity.self,
            DemoStateEntity.self,
            AlarmEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
