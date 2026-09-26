import SwiftUI
import SwiftData
import UserNotifications

@main
struct UpTimePrizesApp: App {

    // MARK: - Shared objects

    // Shared with the lock-screen Dismiss (MorningStarter), so a morning
    // started there is the same morning the app shows.
    @StateObject private var audioManager = MorningStarter.audio
    @StateObject private var stageCoordinator = MorningStarter.stages
    @StateObject private var storeKit = StoreKitManager()

    // MARK: - Alarm state

    @State private var showAlarm: Bool = false

    // MARK: - Model container

    var container: ModelContainer { Self.sharedContainer }

    static let sharedContainer: ModelContainer = {
        let schema = Schema([
            JourneyEntity.self,
            SongEntity.self,
            DemoStateEntity.self,
            AlarmEntity.self,
            MorningRecordEntity.self,
            StarredSongEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A store that cannot migrate must never crash-loop an alarm app
            // (builds 119→122 did exactly that). Every row is either a
            // projection of the manifest or reseedable device state, so the
            // recovery is: delete the store, start fresh, reseed on launch.
            UpTimeLog.seed.error("[SEED] store failed to load — deleting and reseeding: \(error, privacy: .public)")
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
                    try? fm.removeItem(at: appSupport.appendingPathComponent(suffix))
                }
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer even after store reset: \(error)")
            }
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
