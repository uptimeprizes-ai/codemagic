import SwiftUI
import SwiftData

// MARK: - AlarmView
//
// The alarm screen (Android AlarmActivity.AlarmScreen): a live clock, the
// journey as an eyebrow, "Today’s Prize" until the Prize plays — then the
// song's own title and a star — the stage name during the Invite and the
// Nudge, Replay once after the Prize, Snooze during the first two stages,
// and an understated Dismiss that is always there.

struct AlarmView: View {

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var alarms: [AlarmEntity]
    @Query private var starred: [StarredSongEntity]

    @ObservedObject var stageCoordinator: StageCoordinator
    @ObservedObject var audioManager: AudioPlayerManager

    var onDismiss: () -> Void
    var onSnooze: () -> Void

    private var stage: StageCoordinator.Stage { stageCoordinator.currentStage }
    private var prizeRevealed: Bool { stage == .stage3 || stage == .replay }
    private var snoozeMinutes: Int { alarms.first?.snoozeMinutes ?? AlarmEngine.defaultSnoozeMinutes }

    private var journeyLabel: String {
        guard let journeyId = stageCoordinator.currentSong?.journeyId,
              let title = journeys.first(where: { $0.id == journeyId })?.title else {
            return "MORNING MELODIES"
        }
        return title.uppercased()
    }

    private var songTitle: String {
        guard prizeRevealed, let title = stageCoordinator.currentSong?.title, !title.isEmpty else {
            return "Today\u{2019}s Prize"
        }
        return title
    }

    private var isStarred: Bool {
        guard let id = stageCoordinator.currentSong?.id else { return false }
        return starred.contains { $0.songId == id }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                        AnalogClockFace(date: timeline.date)
                    }
                    .frame(width: 200, height: 200)

                    Spacer().frame(height: 24)

                    Text(journeyLabel)
                        .font(.playfair(13))
                        .tracking(0.14)
                        .foregroundColor(BrassPaper.eyebrow)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 6)

                    Text(songTitle)
                        .font(.playfair(28, semibold: true))
                        .foregroundColor(BrassPaper.ink)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.white.opacity(0.55), radius: 1, x: 0, y: 1.5)

                    if prizeRevealed, stageCoordinator.currentSong != nil {
                        Spacer().frame(height: 8)
                        StarButton(isStarred: isStarred, action: toggleStar)
                    }

                    Spacer().frame(height: 32)

                    if stage == .stage1 || stage == .stage2 {
                        Text(stage == .stage1 ? "THE INVITE" : "THE NUDGE")
                            .font(.playfair(27, semibold: true))
                            .foregroundColor(BrassPaper.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    Spacer().frame(height: 48)

                    VStack(spacing: 0) {
                        if stage == .replay && stageCoordinator.replayAvailable {
                            Button { stageCoordinator.handleReplay() } label: {
                                Text("Replay")
                                    .font(.playfair(16, semibold: true))
                                    .foregroundColor(BrassPaper.brass1)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(
                                        LinearGradient(
                                            colors: [BrassPaper.brass2.opacity(0.3), BrassPaper.brass1.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Replay current stage")
                            Spacer().frame(height: 16)
                        }

                        // Snooze during the Invite and the Nudge only; from the
                        // Prize on, the only way out is Dismiss.
                        if stage == .stage1 || stage == .stage2 {
                            Button(action: onSnooze) {
                                Text("Snooze \u{00B7} \(snoozeMinutes) min")
                                    .font(.playfair(16, semibold: true))
                                    .foregroundColor(Color(argb: 0xFFFFF8E8))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(argb: 0xFFD7C08F), Color(argb: 0xFF9B7B48)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Snooze alarm for \(snoozeMinutes) minutes")
                            Spacer().frame(height: 16)
                        }

                        Button(action: onDismiss) {
                            Text("Dismiss")
                                .font(.playfair(16))
                                .foregroundColor(BrassPaper.inkSoft)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss alarm")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .statusBarHidden(true)
    }

    private func toggleStar() {
        guard let id = stageCoordinator.currentSong?.id else { return }
        if let existing = starred.first(where: { $0.songId == id }) {
            context.delete(existing)
        } else {
            context.insert(StarredSongEntity(songId: id))
        }
        try? context.save()
    }
}

// MARK: - StarButton

/// ★ / ☆, as on Android: gold when starred, a muted brass outline when not.
struct StarButton: View {
    let isStarred: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isStarred ? "\u{2605}" : "\u{2606}")
                .font(.system(size: 28))
                .foregroundColor(isStarred ? Color(argb: 0xFFD4A843) : Color(argb: 0xFFB0A080))
                .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isStarred ? "Remove from favorites" : "Add to favorites")
    }
}
