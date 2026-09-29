import SwiftUI

// MARK: - DayNineView
//
// The one-time acknowledgment that the catalog is open (Android
// DayNineTransitionDialog): shown once the ninth Genesis morning has
// counted, closed only by its button. No animation, no confetti, no
// reward. Copy is the shipping Android wording.

struct DayNineView: View {
    let onExplore: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    Text("The catalog is open.")
                        .font(.playfair(32, semibold: true))
                        .foregroundColor(BrassPaper.ink)
                        .lineSpacing(8)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 28)

                    VStack(spacing: 18) {
                        paragraph("Welcome to the rest of UpTime Prizes. The full catalog is open to you now — explore it at your pace.")
                        paragraph("Whatever you choose — one journey, several, or nothing at all — you are welcome here.")
                    }

                    Spacer().frame(height: 40)

                    Button(action: onExplore) {
                        Text("Explore the catalog")
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
