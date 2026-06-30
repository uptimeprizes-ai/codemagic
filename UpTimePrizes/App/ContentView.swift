import SwiftUI
import SwiftData
import UserNotifications

// MARK: - NotificationDelegate

/// Handles foreground notification delivery and routes alarm notifications
/// to the in-app alarm UI.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {

    var onAlarmFired: (() -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.userInfo["type"] as? String == "alarm" {
            // Show alarm UI in-app instead of a banner
            DispatchQueue.main.async {
                self.onAlarmFired?()
                NotificationCenter.default.post(name: AlarmEngine.alarmFiredNotificationName, object: nil)
            }
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.userInfo["type"] as? String == "alarm" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AlarmEngine.alarmFiredNotificationName, object: nil)
            }
        }
        completionHandler()
    }
}

// MARK: - ContentView

struct ContentView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context

    // MARK: - Observed

    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var stageCoordinator: StageCoordinator
    @ObservedObject var storeKit: StoreKitManager
    @Binding var showAlarm: Bool

    // MARK: - State

    @State private var alarmEngine: AlarmEngine?
    @State private var isSeeded: Bool = false
    @StateObject private var notificationDelegate = NotificationDelegate()

    // MARK: - Body

    var body: some View {
        Group {
            if isSeeded, let engine = alarmEngine {
                HomeView(
                    alarmEngine: engine,
                    audioManager: audioManager,
                    stageCoordinator: stageCoordinator,
                    storeKit: storeKit
                )
                .fullScreenCover(isPresented: $showAlarm) {
                    AlarmView(
                        stageCoordinator: stageCoordinator,
                        audioManager: audioManager,
                        onDismiss: {
                            engine.handleAlarmDismissed()
                            stageCoordinator.stopAlarm()
                            showAlarm = false
                        }
                    )
                }
                .onChange(of: showAlarm) { _, newValue in
                    if newValue {
                        // Start alarm audio when alarm view appears
                        if let song = engine.currentSong(from: audioManager) {
                            // Resolve subdirectory using the active journey ID
                            let sub = engine.subdirectory(for: song.id.hasPrefix("demo") ? "demo" : (song.id.hasPrefix("special") ? "special-day" : "library-a"))
                            stageCoordinator.startAlarm(song: song, subdirectory: sub, audioManager: audioManager)
                        }
                    }
                }
            } else {
                ProgressView()
                    .tint(Color("brass"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color("paper").ignoresSafeArea())
            }
        }
        .task {
            await setup()
        }
    }

    // MARK: - Setup

    @MainActor
    private func setup() async {
        // Seed database
        DatabaseSeeder.seed(context: context)
        isSeeded = true

        // Create AlarmEngine
        let engine = AlarmEngine(context: context)
        alarmEngine = engine

        // Configure StoreKit with model context
        storeKit.configure(context: context)

        // Reschedule alarm from persisted state
        engine.rescheduleFromPersistedState()

        // Set up notification delegate
        notificationDelegate.onAlarmFired = { [weak engine] in
            engine?.isAlarmActive = true
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Request notification permission on first launch
        _ = await engine.requestNotificationPermission()
    }
}
