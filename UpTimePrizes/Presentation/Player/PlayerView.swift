import SwiftUI
import AVFoundation
import SwiftData

// MARK: - PlayerView

/// The Player tab — shows the alarm card with time picker and enable/disable toggle,
/// and lists songs for journeys that are UNLOCKED_FOR_PLAYBACK.
struct PlayerView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var alarms: [AlarmEntity]
    @Query private var songs: [SongEntity]

    // MARK: - Observed

    @ObservedObject var alarmEngine: AlarmEngine
    @ObservedObject var audioManager: AudioPlayerManager

    // MARK: - State

    @State private var showTimePicker: Bool = false
    @State private var selectedHour: Int = 7
    @State private var selectedMinute: Int = 0
    @State private var selectedRepeatDays: Set<Int> = []
    @State private var playingPreviewId: String? = nil

    // MARK: - Computed

    private var alarm: AlarmEntity? { alarms.first }

    private var activeJourney: JourneyEntity? {
        journeys.first(where: { $0.isActive })
    }

    private var unlockedJourneys: [JourneyEntity] {
        journeys.filter { $0.purchaseState == "UNLOCKED_FOR_PLAYBACK" }
    }

    private var catalystJourney: JourneyEntity? {
        journeys.first(where: { $0.type == "SPECIAL_DAY" && $0.purchaseState == "UNLOCKED_FOR_PLAYBACK" })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    alarmCard
                    journeyProgressCard
                    if !unlockedJourneys.isEmpty {
                        unlockedSongsSection
                    }
                    if catalystJourney != nil {
                        catalystSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color("paper").ignoresSafeArea())
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            if let alarm = alarm {
                selectedHour = alarm.hour
                selectedMinute = alarm.minute
                selectedRepeatDays = Set(alarm.repeatDays)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
    }

    // MARK: - Alarm card

    private var alarmCard: some View {
        VStack(spacing: 0) {
            // Time display
            Button {
                showTimePicker = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formattedTime)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 52))
                        .foregroundColor(Color("ink"))
                    Text(amPmLabel)
                        .font(.custom("PlayfairDisplay-Regular", size: 20))
                        .foregroundColor(Color("ink").opacity(0.6))
                        .padding(.bottom, 6)
                }
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 16)

            // Repeat days
            repeatDaysRow

            Spacer().frame(height: 20)

            // Enable toggle
            HStack {
                Text(alarm?.isEnabled == true ? "Alarm on" : "Alarm off")
                    .font(.custom("PlayfairDisplay-Regular", size: 15))
                    .foregroundColor(Color("ink").opacity(0.7))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { alarm?.isEnabled ?? false },
                    set: { enabled in
                        toggleAlarm(enabled: enabled)
                    }
                ))
                .tint(Color("brass"))
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color("ink").opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Journey progress card

    private var journeyProgressCard: some View {
        Group {
            if let journey = activeJourney {
                VStack(alignment: .leading, spacing: 10) {
                    Text(journey.title)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                        .foregroundColor(Color("ink"))

                    if journey.purchaseState == "ACTIVE_IN_PROGRESS" {
                        let progress = Double(journey.completedDays) / Double(journey.totalDays)
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progress)
                                .tint(Color("brass"))
                            Text("Day \(journey.completedDays) of \(journey.totalDays)")
                                .font(.custom("PlayfairDisplay-Regular", size: 13))
                                .foregroundColor(Color("ink").opacity(0.6))
                        }
                    } else if journey.purchaseState == "UNLOCKED_FOR_PLAYBACK" {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("brass"))
                            Text("Library unlocked for free playback")
                                .font(.custom("PlayfairDisplay-Regular", size: 13))
                                .foregroundColor(Color("ink").opacity(0.7))
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color("ink").opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
    }

    // MARK: - Unlocked songs section

    private var unlockedSongsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(unlockedJourneys, id: \.id) { journey in
                if journey.type != "SPECIAL_DAY" {
                    let journeySongs = songs
                        .filter { $0.libraryId == journey.id && $0.isAvailable }
                        .sorted { $0.dayNumber < $1.dayNumber }

                    if !journeySongs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(journey.title)
                                .font(.custom("PlayfairDisplay-SemiBold", size: 15))
                                .foregroundColor(Color("ink"))

                            ForEach(journeySongs, id: \.id) { song in
                                songRow(song: song, subdirectory: subdirectory(for: journey.id))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Catalyst section

    private var catalystSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The Catalyst Tracks")
                .font(.custom("PlayfairDisplay-SemiBold", size: 15))
                .foregroundColor(Color("ink"))

            let catalystSongs = songs
                .filter { $0.libraryId == "special-day" && $0.isAvailable }
                .sorted { $0.dayNumber < $1.dayNumber }

            ForEach(catalystSongs, id: \.id) { song in
                songRow(song: song, subdirectory: nil)
            }
        }
    }

    // MARK: - Song row

    private func songRow(song: SongEntity, subdirectory: String?) -> some View {
        HStack(spacing: 14) {
            Button {
                togglePreview(song: song, subdirectory: subdirectory)
            } label: {
                Image(systemName: playingPreviewId == song.id ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color("brass"))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.custom("PlayfairDisplay-SemiBold", size: 15))
                    .foregroundColor(Color("ink"))
                Text("Day \(song.dayNumber)")
                    .font(.custom("PlayfairDisplay-Regular", size: 12))
                    .foregroundColor(Color("ink").opacity(0.5))
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Repeat days row

    private var repeatDaysRow: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                Button {
                    toggleRepeatDay(day)
                } label: {
                    Text(dayAbbreviation(day))
                        .font(.custom("PlayfairDisplay-Regular", size: 12))
                        .foregroundColor(selectedRepeatDays.contains(day) ? Color("paper") : Color("ink").opacity(0.6))
                        .frame(width: 34, height: 34)
                        .background(selectedRepeatDays.contains(day) ? Color("brass") : Color("ink").opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Time picker sheet

    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    "Alarm Time",
                    selection: Binding(
                        get: {
                            var components = DateComponents()
                            components.hour = selectedHour
                            components.minute = selectedMinute
                            return Calendar.current.date(from: components) ?? Date()
                        },
                        set: { date in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                            selectedHour = components.hour ?? 7
                            selectedMinute = components.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .padding()
            .navigationTitle("Set Alarm Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAlarmTime()
                        showTimePicker = false
                    }
                    .foregroundColor(Color("brass"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showTimePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func toggleAlarm(enabled: Bool) {
        guard let alarm = alarm else { return }
        alarm.isEnabled = enabled
        try? context.save()
        if enabled {
            alarmEngine.scheduleAlarm(hour: alarm.hour, minute: alarm.minute, repeatDays: alarm.repeatDays)
        } else {
            alarmEngine.cancelAlarm()
        }
    }

    private func saveAlarmTime() {
        guard let alarm = alarm else { return }
        alarm.hour = selectedHour
        alarm.minute = selectedMinute
        alarm.repeatDays = Array(selectedRepeatDays)
        try? context.save()
        if alarm.isEnabled {
            alarmEngine.scheduleAlarm(hour: selectedHour, minute: selectedMinute, repeatDays: Array(selectedRepeatDays))
        }
    }

    private func toggleRepeatDay(_ day: Int) {
        if selectedRepeatDays.contains(day) {
            selectedRepeatDays.remove(day)
        } else {
            selectedRepeatDays.insert(day)
        }
    }

    private func togglePreview(song: SongEntity, subdirectory: String?) {
        if playingPreviewId == song.id {
            audioManager.stopAll()
            playingPreviewId = nil
        } else {
            // Only one song plays at a time
            audioManager.stopAll()
            playingPreviewId = song.id
            // Play Stage 3 region (the full song) for preview
            if let manifest = AudioPlayerManager.loadManifest(),
               let manifestSong = manifest.libraries[song.libraryId]?.songs.first(where: { $0.filename == song.filename }) {
                audioManager.playStage3(
                    filename: song.filename,
                    subdirectory: subdirectory,
                    region: manifestSong.regions.stage3
                ) { [weak audioManager] in
                    Task { @MainActor in
                        audioManager?.stopAll()
                    }
                }
            } else {
                // Fallback: play full file
                audioManager.play(filename: song.filename, subdirectory: subdirectory)
            }
        }
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let h = selectedHour % 12 == 0 ? 12 : selectedHour % 12
        let m = String(format: "%02d", selectedMinute)
        return "\(h):\(m)"
    }

    private var amPmLabel: String {
        selectedHour < 12 ? "AM" : "PM"
    }

    private func dayAbbreviation(_ day: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][day - 1]
    }

    private func subdirectory(for journeyId: String) -> String? {
        journeyId == "demo" ? "demo" : nil
    }
}

// MARK: - AudioPlayerManager convenience

extension AudioPlayerManager {
    func play(filename: String, subdirectory: String?) {
        let url: URL?
        if let sub = subdirectory {
            url = Bundle.main.url(forResource: filename, withExtension: "m4a", subdirectory: sub)
                ?? Bundle.main.url(forResource: filename, withExtension: "m4a")
        } else {
            url = Bundle.main.url(forResource: filename, withExtension: "m4a")
        }
        guard let url = url else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.play()
        } catch {
            print("[AudioPlayerManager] play(filename:subdirectory:) error: \(error)")
        }
    }
}
