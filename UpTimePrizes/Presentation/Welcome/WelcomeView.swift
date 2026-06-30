import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to UpTime Prizes")
                .font(.playfairSemiBold(size: 28))
                .foregroundColor(Color("ink"))

            Text("UpTime Prizes is free. The app is yours to use, and five songs come with it — The Genesis.")
                .font(.playfair(size: 16))
                .foregroundColor(Color("ink"))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("paper").ignoresSafeArea())
    }
}

#Preview {
    WelcomeView()
}
