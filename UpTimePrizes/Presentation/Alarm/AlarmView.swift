import SwiftUI
import SwiftData

// MARK: - AlarmView

/// Full-screen alarm view presented when the alarm sounds.
/// Shows the current stage, song title, journey name, Snooze and Dismiss buttons.
/// Stage auto-advances when Stage 1/2 regions end; Stage 3 shows Replay button.
struct AlarmView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var alarms: [AlarmEntity]

    // MARK: - Observed

    @ObservedObject var stageCoordinator: StageCoordinator
    @ObservedObject var audioManager: AudioPlayerManager

    // MARK: - Callbacks

    var onDismiss: () -> Void
    var onSnooze: () -> Void

    // MARK: - Computed

    private var activeJourney: JourneyEntity? {
        journeys.first(where: { $0.isActive })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color("paper")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Stage badge
                stageBadge

                Spacer().frame(height: 40)

                // Song title
                if let song = stageCoordinator.currentSong {
                    Text(song.title)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 28))
                        .foregroundColor(Color("ink"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 12)

                // Journey name
                if let journey = activeJourney {
                    Text(journey.title)
                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                        .foregroundColor(Color("ink").opacity(0.6))
                }

                Spacer()

                // Replay button (Stage 3 finished)
                if stageCoordinator.currentStage == .replay && stageCoordinator.replayAvailable {
                    replayButton
                    Spacer().frame(height: 20)
                }

                // Dismiss button
                dismissButton

                Spacer().frame(height: 16)

                // Snooze button (only visible during Stage 1 and Stage 2)
                if stageCoordinator.currentStage == .stage1 || stageCoordinator.currentStage == .stage2 {
                    snoozeButton
                }

                Spacer().frame(height: 48)
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Stage badge

    private var stageBadge: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(StageCoordinator.Stage.allCases.filter { $0 != .replay }, id: \.self) { stage in
                    Circle()
                        .fill(stageCoordinator.currentStage == stage || stageCoordinator.stageIndex > stage.index
                              ? Color("brass")
                              : Color("ink").opacity(0.15))
                        .frame(width: 10, height: 10)
                }
            }

            Text(stageCoordinator.stageName)
                .font(.custom("PlayfairDisplay-SemiBold", size: 13))
                .foregroundColor(Color("brass"))
                .tracking(2)
                .textCase(.uppercase)
        }
    }

    // MARK: - Replay button

    private var replayButton: some View {
        Button {
            stageCoordinator.handleReplay()
        } label: {
            Text("Replay")
                .font(.custom("PlayfairDisplay-Regular", size: 17))
                .foregroundColor(Color("brass"))
                .padding(.vertical, 14)
                .padding(.horizontal, 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color("brass"), lineWidth: 1.5)
                )
        }
    }

    // MARK: - Dismiss button

    private var dismissButton: some View {
        Button {
            onDismiss()
        } label: {
            // "Dismiss" is the specification's own term (§2.4); the previous
            // label was agent-written copy with no curator ruling.
            Text("Dismiss")
                .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                .foregroundColor(Color("paper"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color("brass"))
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Snooze button

    private var snoozeButton: some View {
        Button {
            onSnooze()
        } label: {
            Text("Snooze \(alarms.first?.snoozeMinutes ?? AlarmEngine.defaultSnoozeMinutes) min")
                .font(.custom("PlayfairDisplay-Regular", size: 15))
                .foregroundColor(Color("ink").opacity(0.5))
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
