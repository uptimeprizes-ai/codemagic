import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack {
            Text("Welcome to UpTime Prizes")
                .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 28))
                .foregroundColor(DesignTokens.ink)
            
            Text("UpTime Prizes is free. The app is yours to use, and five songs come with it — The Genesis. Two were recently added.")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 16))
                .foregroundColor(DesignTokens.ink)
                .multilineTextAlignment(.center)
                .padding()
        }
        .background(DesignTokens.paper)
    }
}
