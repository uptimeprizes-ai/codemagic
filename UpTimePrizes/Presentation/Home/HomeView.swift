import SwiftUI

struct HomeView: View {

    @ObservedObject var alarmEngine: AlarmEngine
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var stageCoordinator: StageCoordinator
    @ObservedObject var storeKit: StoreKitManager

    var body: some View {
        TabView {
            HomeScreenView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            PlayerView(alarmEngine: alarmEngine, audioManager: audioManager)
                .tabItem {
                    Label("Alarm", systemImage: "alarm.fill")
                }

            DiscoverView(storeKit: storeKit)
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }

            SettingsView(alarmEngine: alarmEngine)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Color("brass"))
    }
}
