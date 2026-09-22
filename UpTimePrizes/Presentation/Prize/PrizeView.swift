import SwiftUI

// MARK: - PrizeView
//
// Appears after every Dismiss that counts a morning, in any stage, and after
// auto-silence (§2.5). "Continue" returns to the app. It is presented inside
// the same full-screen cover as the alarm, so the alarm screen can never
// close before the Prize screen renders (Android bug guard 1).
//
// Header rules:
//   [Journey] · Morning x of y
//   [Journey] · Complete            on the last morning
//   the journey name alone          for a Catalyst or fallback morning
// Messages are the curator's, verbatim, and say only what is now true.

// Copy selection lives on the outcome so the rules are unit-testable.
extension AlarmEngine.MorningOutcome {

    var prizeHeader: String {
        if heldStreakOnly {
            return journeyTitle
        }
        if journeyComplete {
            return "\(journeyTitle) · Complete"
        }
        return "\(journeyTitle) · Morning \(morningNumber) of \(totalDays)"
    }

    var prizeMessage: String {
        if heldStreakOnly {
            return CuratorCopy.prizeMessageCatalystOrFallback
        }
        if journeyComplete {
            return CuratorCopy.prizeMessageJourneyComplete
        }
        if reachedPrize {
            return CuratorCopy.prizeMessagePrizeReached
        }
        return CuratorCopy.prizeMessageDismissedEarly
    }
}

struct PrizeView: View {

    let outcome: AlarmEngine.MorningOutcome
    var onContinue: () -> Void

    private var headerText: String { outcome.prizeHeader }
    private var messageText: String { outcome.prizeMessage }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("paper")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(headerText)
                    .font(.custom("PlayfairDisplay-SemiBold", size: 14))
                    .foregroundColor(Color("brass"))
                    .tracking(2)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 28)

                Text(messageText)
                    .font(.custom("PlayfairDisplay-SemiBold", size: 26))
                    .foregroundColor(Color("ink"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                Button {
                    onContinue()
                } label: {
                    Text(CuratorCopy.prizeContinue)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                        .foregroundColor(Color("paper"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color("brass"))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 48)
            }
        }
        .statusBarHidden(true)
    }
}
