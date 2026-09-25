import SwiftUI

// MARK: - WelcomeView
//
// First launch, shown exactly once before the main interface (Android
// WelcomePage): no skip and no close — the person taps Begin. Copy is the
// shipping Android wording.

struct WelcomeView: View {
    let onBegin: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    Text("Welcome.")
                        .font(.playfair(38, semibold: true))
                        .foregroundColor(BrassPaper.ink)

                    Spacer().frame(height: 28)
                    VStack(spacing: 18) {
                        paragraph("UpTime Prizes is free. The app is yours to use, and five songs come with it — The Genesis. Two were recently added.")
                        paragraph("For the next nine mornings, your alarm will unfold in three stages: the Invite, the Nudge, and the Prize. The song itself, the UpTime swing — and the morning is yours. All music is original, inspired by big band swing and the sounds of Yesteryear.")
                        paragraph("On the ninth day, our growing catalog opens to you. Your access to the Genesis songs never expires.")
                    }

                    Spacer().frame(height: 40)

                    Button(action: onBegin) {
                        Text("Begin")
                            .font(.playfair(16, semibold: true))
                            .foregroundColor(Color(argb: 0xFFFFF8E8))
                            .frame(maxWidth: 360)
                            .padding(.vertical, 16)
                            .background(BrassPaper.brass1)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.playfair(16))
            .foregroundColor(BrassPaper.ink)
            .lineSpacing(8)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
