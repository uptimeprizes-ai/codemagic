import SwiftUI
import SwiftData

// MARK: - PlayerView
//
// The Player tab: play what you already own (Android screen map §3). It
// never sells anything and never shows a journey you do not own. Setting
// the alarm lives on Settings; buying lives on Discover.
//
// Top to bottom: the day pill, what is playing now, the CATALOG (hidden
// until the ninth counted Genesis morning), STARRED, and the footer. A
// journey's songs appear only once it is finished — except the Catalyst
// Tracks, listed the moment they are owned (see CatalogRules).
//
// Still to come, awaiting the App Builder's exact composition: the full
// Morning Prize card (waveform, scrubber, skip, journey ring).

struct PlayerView: View {

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var songs: [SongEntity]
    @Query(sort: \StarredSongEntity.starredAt) private var starred: [StarredSongEntity]
    @Query private var demoStates: [DemoStateEntity]

    @ObservedObject var audioManager: AudioPlayerManager

    @State private var playingSongId: String?

    // MARK: - Computed

    private var genesisCompletedDays: Int { demoStates.first?.completedDays ?? 0 }

    private var activeJourney: JourneyEntity? { journeys.first(where: { $0.isActive }) }

    private var catalogRows: [CatalogRules.JourneyFacts] {
        CatalogRules.catalogRows(
            journeys.map { CatalogRules.JourneyFacts($0) },
            genesisCompletedDays: genesisCompletedDays
        )
    }

    private var starredSongs: [SongEntity] {
        starred.compactMap { star in songs.first(where: { $0.id == star.songId }) }
    }

    private var playingSong: SongEntity? {
        guard let id = playingSongId else { return nil }
        return songs.first(where: { $0.id == id })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let journey = activeJourney {
                        dayPill(for: journey)
                    }
                    if let song = playingSong {
                        nowPlayingCard(song)
                    }
                    if !catalogRows.isEmpty {
                        catalogSection
                    }
                    if !starredSongs.isEmpty {
                        starredSection
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color("paper").ignoresSafeArea())
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: audioManager.isPlaying) { _, playing in
            if !playing { playingSongId = nil }
        }
        .onDisappear { stop() }
    }

    // MARK: - Day pill

    private func dayPill(for journey: JourneyEntity) -> some View {
        Text(CatalogRules.dayPill(CatalogRules.JourneyFacts(journey)))
            .font(.custom("PlayfairDisplay-SemiBold", size: 13))
            .tracking(2)
            .foregroundColor(Color("brass"))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color("brass"), lineWidth: 1))
    }

    // MARK: - Now playing

    private func nowPlayingCard(_ song: SongEntity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOW PLAYING")
                .font(.custom("PlayfairDisplay-SemiBold", size: 12))
                .tracking(2)
                .foregroundColor(Color("brass"))
            HStack(spacing: 14) {
                Button { stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color("brass"))
                }
                .buttonStyle(.plain)
                Text(song.title)
                    .font(.custom("PlayfairDisplay-SemiBold", size: 20))
                    .foregroundColor(Color("ink"))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color("ink").opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("CATALOG")
            ForEach(catalogRows, id: \.id) { row in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(title(for: row.id))
                            .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                            .foregroundColor(Color("ink"))
                        Spacer()
                        statePill(CatalogRules.rowPill(row))
                    }
                    if CatalogRules.songsVisible(row) {
                        ForEach(journeySongs(row.id), id: \.id) { song in
                            songRow(song, showsUnstar: false)
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Starred

    private var starredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("STARRED")
            ForEach(starredSongs, id: \.id) { song in
                songRow(song, showsUnstar: true)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("✦ UPTIME PRIZES ✦")
            .font(.custom("PlayfairDisplay-Regular", size: 12))
            .tracking(3)
            .foregroundColor(Color("brass").opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
    }

    // MARK: - Pieces

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.custom("PlayfairDisplay-SemiBold", size: 13))
            .tracking(2)
            .foregroundColor(Color("ink").opacity(0.6))
    }

    private func statePill(_ text: String) -> some View {
        Text(text)
            .font(.custom("PlayfairDisplay-Regular", size: 12))
            .foregroundColor(Color("paper"))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color("brass"))
            .clipShape(Capsule())
    }

    private func songRow(_ song: SongEntity, showsUnstar: Bool) -> some View {
        HStack(spacing: 14) {
            if song.isAvailable {
                Button { togglePlay(song) } label: {
                    Image(systemName: playingSongId == song.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color("brass"))
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.custom("PlayfairDisplay-SemiBold", size: 15))
                    .foregroundColor(Color("ink"))
                if !song.isAvailable {
                    Text(CuratorCopy.songNotReady)
                        .font(.custom("PlayfairDisplay-Regular", size: 12))
                        .foregroundColor(Color("ink").opacity(0.5))
                }
            }
            Spacer()
            if showsUnstar {
                Button { unstar(song) } label: {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color("brass"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Lookups

    private func title(for journeyId: String) -> String {
        journeys.first(where: { $0.id == journeyId })?.title ?? ""
    }

    private func journeySongs(_ journeyId: String) -> [SongEntity] {
        songs.filter { $0.journeyId == journeyId }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Actions

    /// Plays The Prize (the full song) of an owned song; one at a time.
    private func togglePlay(_ song: SongEntity) {
        if playingSongId == song.id {
            stop()
            return
        }
        guard let manifestSong = audioManager.songs(forJourneyId: song.journeyId)
            .first(where: { $0.id == song.id }) else { return }
        let manager = audioManager
        manager.stopAll()
        playingSongId = song.id
        let started = manager.playStage3(
            filename: manifestSong.fileStem,
            subdirectory: song.journeyId == CatalogRules.genesisId ? "Audio/genesis" : nil,
            region: manifestSong.fullRegion
        ) { [weak manager] in
            Task { @MainActor in manager?.stopAll() }
        }
        if !started { playingSongId = nil }
    }

    private func stop() {
        audioManager.stopAll()
        playingSongId = nil
    }

    private func unstar(_ song: SongEntity) {
        if let star = starred.first(where: { $0.songId == song.id }) {
            context.delete(star)
            try? context.save()
        }
    }
}
