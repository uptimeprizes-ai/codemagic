import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false
    
    var body: some View {
        Group {
            if hasSeeded {
                HomeView()
            } else {
                ProgressView()
            }
        }
        .task {
            DatabaseSeeder.seed(context: modelContext)
            hasSeeded = true
        }
    }
}
