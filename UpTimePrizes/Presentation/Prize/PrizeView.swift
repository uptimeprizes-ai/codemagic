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
    var songTitle: String = ""
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
    //
    // Layout from Android's PrizeRevealScreen: an eyebrow, the song's title
    // with its star, the journey badge, the curator's message, the star
    // hint, and Continue.

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                Text("Your melody for this morning")
                    .font(.playfair(13))
                    .foregroundColor(BrassPaper.inkSoft)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 16)

                HStack(spacing: 12) {
                    if !songTitle.isEmpty {
                        Text(songTitle)
                            .font(.playfair(27, semibold: true))
                            .foregroundColor(BrassPaper.ink)
                            .multilineTextAlignment(.center)
                    }
                    if songId != nil {
                        StarButton(isStarred: isStarred, action: toggleStar)
                    }
                }

                Spacer().frame(height: 12)

                Text(headerText)
                    .font(.playfair(13))
                    .foregroundColor(Color(argb: 0xFFF8F1DE))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color(argb: 0xFFD7BD88), Color(argb: 0xFF8E6E3C)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())

                Spacer().frame(height: 32)

                Text(messageText)
                    .font(.playfair(16))
                    .lineSpacing(7)
                    .foregroundColor(BrassPaper.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)

                if songId != nil {
                    Spacer().frame(height: 16)
                    Text(isStarred ? "★ Starred — find it in your favorites" : "Tap ☆ to star this song")
                        .font(.playfair(12))
                        .foregroundColor(isStarred ? BrassPaper.brassHighlight : BrassPaper.inkSoft)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 48)

                Button(action: onContinue) {
                    Text(CuratorCopy.prizeContinue)
                        .font(.playfair(14, semibold: true))
                        .foregroundColor(Color(argb: 0xFFFFF8E8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(argb: 0xFFD7C08F), Color(argb: 0xFF9B7B48)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBarHidden(true)
    }
}
