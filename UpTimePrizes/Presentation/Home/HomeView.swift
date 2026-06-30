import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PlayerView()
                .tabItem {
                    Label("Player", systemImage: "music.note")
                }
                .tag(0)
            
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(DesignTokens.brass)
    }
}
