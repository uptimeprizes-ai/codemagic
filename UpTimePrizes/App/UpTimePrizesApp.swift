import SwiftUI
import SwiftData
import UserNotifications

@main
struct UpTimePrizesApp: App {

    // MARK: - Shared objects

    @StateObject private var audioManager = AudioPlayerManager()
    @StateObject private var stageCoordinator = StageCoordinator()
    @StateObject private var storeKit = StoreKitManager()

    // MARK: - Alarm state

    @State private var showAlarm: Bool = false

    // MARK: - Model container

    let container: ModelContainer = {
        let schema = Schema([
            JourneyEntity.self,
            SongEntity.self,
            DemoStateEntity.self,
            AlarmEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView(
                audioManager: audioManager,
                stageCoordinator: stageCoordinator,
                storeKit: storeKit,
                showAlarm: $showAlarm
            )
            .modelContainer(container)
            .onReceive(NotificationCenter.default.publisher(for: AlarmEngine.alarmFiredNotificationName)) { _ in
                showAlarm = true
            }
        }
    }
}
