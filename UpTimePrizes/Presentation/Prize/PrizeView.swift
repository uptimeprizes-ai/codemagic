import SwiftUI
import SwiftData

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
        // Curator, 2026-09-23: a morning nobody answered leads the message,
        // before anything else — and where the line underneath carries a
        // fact of its own (a completed journey, a Catalyst day), the two
        // STACK, unheard line first. The experience lines ("the UpTime
        // swing", "tomorrow brings another song") describe a person who was
        // there, so an unheard morning never wears them.
        if wasUnanswered {
            if journeyComplete {
                return CuratorCopy.prizeMessageUnheard + "\n\n" + CuratorCopy.prizeMessageJourneyComplete
            }
            if heldStreakOnly {
                return CuratorCopy.prizeMessageUnheard + "\n\n" + CuratorCopy.prizeMessageCatalystOrFallback
            }
            return CuratorCopy.prizeMessageUnheard
        }
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
    /// The song this morning played; nil hides the star.
    var songId: String? = nil
    var onContinue: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var starred: [StarredSongEntity]

    private var headerText: String { outcome.prizeHeader }
    private var messageText: String { outcome.prizeMessage }

    private var isStarred: Bool {
        guard let songId else { return false }
        return starred.contains { $0.songId == songId }
    }

    /// Star or unstar this morning's song (screen map §3.4 — starred songs
    /// are playable from the Player's STARRED section).
    private func toggleStar() {
        guard let songId else { return }
        if let existing = starred.first(where: { $0.songId == songId }) {
            context.delete(existing)
        } else {
            context.insert(StarredSongEntity(songId: songId))
        }
        try? context.save()
    }

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

                if songId != nil {
                    Spacer().frame(height: 28)
                    Button(action: toggleStar) {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundColor(Color("brass"))
                    }
                    .buttonStyle(.plain)
                }

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
