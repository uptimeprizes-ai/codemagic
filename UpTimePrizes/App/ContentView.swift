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
    @Environment(\.scenePhase) private var scenePhase

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
                        },
                        onSnooze: {
                            engine.snoozeAlarm()
                            stageCoordinator.stopAlarm()
                            showAlarm = false
                        }
                    )
                }
                .onChange(of: showAlarm) { _, newValue in
                    if newValue {
                        if let song = engine.currentSong(from: audioManager) {
                            let sub = engine.subdirectory(for: song.journeyId)
                            stageCoordinator.startAlarm(song: song, subdirectory: sub, audioManager: audioManager)
                        }
                    }
                }
                // Bug 1 fix: Re-verify alarm scheduling every time the app becomes active.
                // This catches cases where the OS cleared pending notifications (e.g., after
                // an app update from TestFlight/App Store).
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await engine.verifyAndRescheduleIfNeeded()
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
        // Bug 3 fix: Exclude SwiftData store from iCloud backup to prevent
        // stale region data from being restored on device migration.
        BackupExclusion.excludeSwiftDataStoreFromBackup()

        // Seed database (with manifest fingerprint check for Bug 3)
        DatabaseSeeder.seed(context: context)
        isSeeded = true

        // Create AlarmEngine
        let engine = AlarmEngine(context: context)
        alarmEngine = engine

        // Configure StoreKit with model context (Bug 2 fix is inside applyEntitlement)
        storeKit.configure(context: context)

        // Bug 1 fix: Reschedule alarm from persisted state on first launch
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
