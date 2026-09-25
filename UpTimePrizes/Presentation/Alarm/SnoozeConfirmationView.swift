import Foundation
import SwiftUI

// MARK: - SnoozeConfirmationView
//
// Shown for three seconds after the person snoozes (Android
// SnoozeConfirmationScreen): when the next melody comes, and a brass bar
// running down to it. Then the app returns.

struct SnoozeConfirmationView: View {
    let returnAt: Date
    let onDone: () -> Void

    @State private var remaining: CGFloat = 1

    var body: some View {
        ZStack {
            LinearGradient(colors: [BrassPaper.gradientTop, BrassPaper.gradientBot], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("UpTime Prizes")
                    .font(.playfair(22, semibold: true))
                    .foregroundColor(BrassPaper.inkSoft)

                Spacer().frame(height: 48)

                Text("Rest a little longer.")
                    .font(.playfair(28, semibold: true))
                    .foregroundColor(BrassPaper.ink)

                Spacer().frame(height: 16)

                Text("Next melody at \(Self.timeLabel(returnAt))")
                    .font(.playfair(18))
                    .foregroundColor(BrassPaper.inkSoft)

                Spacer().frame(height: 64)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(BrassPaper.ink.opacity(0.12))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(argb: 0xFFD7C08F), Color(argb: 0xFF9B7B48)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * remaining)
                    }
                }
                .frame(height: 3)
                .frame(maxWidth: 220)
            }
            .multilineTextAlignment(.center)
            .padding(32)
        }
        .statusBarHidden(true)
        .onAppear {
            withAnimation(.linear(duration: 3)) {
                remaining = 0
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 3_100_000_000)
            onDone()
        }
    }

    /// "3:45 PM"
    static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
