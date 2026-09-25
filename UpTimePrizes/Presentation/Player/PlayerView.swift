import Foundation
import SwiftUI
import SwiftData

// MARK: - PlayerView
//
// The Player tab: play what you already own (Android screen map §3,
// PlayerPage.kt). It never sells anything and never shows a journey you do
// not own. Setting the alarm lives on Settings; buying lives on Discover.
//
// Top to bottom: MORNING PRIZE and the day pill, the Morning Prize player,
// then (scrolling) the CATALOG — hidden until the ninth counted Genesis
// morning and until something is owned — STARRED, and the footer. See
// CatalogRules for every gate.

struct PlayerView: View {

    @Query private var journeys: [JourneyEntity]
    @Query private var songs: [SongEntity]
    @Query(sort: \StarredSongEntity.starredAt) private var starred: [StarredSongEntity]
    @Query private var demoStates: [DemoStateEntity]
    @Query private var mornings: [MorningRecordEntity]

    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject private var library = LibraryPlayer.shared

    @State private var starredExpanded = false

    // MARK: - Facts

    private var facts: [CatalogRules.JourneyFacts] { journeys.map { CatalogRules.JourneyFacts($0) } }
    private var activeJourney: JourneyEntity? { journeys.first(where: { $0.isActive }) }
    private var genesisCompletedDays: Int { demoStates.first?.completedDays ?? 0 }

    private var dayCount: Int {
        guard let journey = activeJourney else { return 0 }
        let today = MorningLedger.dayKey(for: Date())
        return CatalogRules.dayCount(
            CatalogRules.JourneyFacts(journey),
            genesisCurrentDay: demoStates.first?.currentDay ?? 1,
            countedToday: mornings.contains { $0.dayKey == today }
        )
    }

    private var showsCatalog: Bool {
        CatalogRules.showsCatalog(facts, genesisCompletedDays: genesisCompletedDays)
    }

    /// Every song the person can play here, in the order it is listed.
    private var playlist: [LibraryPlayer.Track] {
        var ids = CatalogRules.ownedRows(facts).filter(CatalogRules.songsVisible).map(\.id)
        if CatalogRules.isCatalystOwned(facts) { ids.append(CatalogRules.catalystId) }
        return ids.flatMap(tracks(forJourneyId:))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 12)
                header
                Spacer().frame(height: 14)
                morningPrizeCard
                Spacer().frame(height: 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if showsCatalog {
                            catalogSection
                        }
                        if !starred.isEmpty {
                            Spacer().frame(height: 8)
                            starredSection
                        }
                        Spacer().frame(height: 8)
                        footer
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("MORNING PRIZE")
                .font(.playfair(10, semibold: true))
                .tracking(3.4)
                .foregroundColor(BrassPaper.ink.opacity(0.55))
            Spacer()
            if let journey = activeJourney, journey.totalDays > 0 {
                BrassPillLabel(text: CatalogRules.dayPill(CatalogRules.JourneyFacts(journey), dayCount: dayCount))
            }
        }
    }

    // MARK: - Morning Prize player

    private var morningPrizeCard: some View {
        let fraction = CatalogRules.progress(dayCount: dayCount, totalDays: activeJourney?.totalDays ?? 0)
        return VStack(alignment: .leading, spacing: 0) {
            // Curator copy, 2026-09-17: never "failed" or "unavailable".
            Text(library.notReady ? "NOT READY YET" : "NOW PLAYING")
                .font(.playfair(10, semibold: true))
                .tracking(3.4)
                .foregroundColor(BrassPaper.brassHighlight)
            Spacer().frame(height: 6)
            Text(library.current?.title ?? activeJourney?.title ?? "Select a song below")
                .font(.playfair(22, semibold: true))
                .foregroundColor(BrassPaper.brassHighlight)
                .lineLimit(1)
                .shadow(color: Color.black.opacity(0.60), radius: 1, x: 0, y: 1)
            if library.notReady {
                Spacer().frame(height: 4)
                Text("This one is still arriving.")
                    .font(.playfair(10, semibold: true))
                    .tracking(3.4)
                    .foregroundColor(BrassPaper.brassHighlight)
            }

            Spacer().frame(height: 14)
            phonograph

            HStack {
                Text("JOURNEY")
                    .font(.mono(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(BrassPaper.brassHighlight.opacity(0.65))
                Spacer()
                Text("\(Int(fraction * 100))% COMPLETE")
                    .font(.mono(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(BrassPaper.brassHighlight)
            }
            .padding(.top, 16)
            .padding(.bottom, 6)

            JourneyBar(fraction: fraction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(BrassPaper.plaqueFill)
        .overlay(alignment: .top) {
            LinearGradient(colors: [BrassPaper.brass2.opacity(0.18), Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(colors: [BrassPaper.brass2.opacity(0.35), BrassPaper.brassDeep.opacity(0.20)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
    }

    /// The recessed row: the brass play button, the waveform, and — once a
    /// song is loaded — the scrubber and skip controls.
    private var phonograph: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                BrassPlayButton(isPlaying: library.isPlaying) {
                    library.togglePlayPause()
                }
                GoldWaveform(animated: library.isPlaying)
                    .frame(height: 44)
            }

            if library.current != nil {
                Spacer().frame(height: 8)
                Slider(
                    value: Binding(
                        get: { Double(library.positionMs) },
                        set: { library.seek(toMs: Int($0)) }
                    ),
                    in: 0...Double(library.durationMs)
                )
                .tint(BrassPaper.brass2)
                HStack {
                    Text(Self.format(ms: library.positionMs))
                        .font(.mono(9, weight: .bold))
                        .tracking(1.8)
                        .foregroundColor(BrassPaper.brassHighlight.opacity(0.70))
                    Spacer()
                    HStack(spacing: 16) {
                        Button { skip(by: -1) } label: {
                            Text("\u{23EE}").font(.system(size: 18)).foregroundColor(BrassPaper.brassHighlight)
                        }
                        Button { skip(by: 1) } label: {
                            Text("\u{23ED}").font(.system(size: 18)).foregroundColor(BrassPaper.brassHighlight)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(Self.format(ms: library.durationMs))
                        .font(.mono(9, weight: .bold))
                        .tracking(1.8)
                        .foregroundColor(BrassPaper.brassHighlight.opacity(0.70))
                }
            }
        }
        .padding(14)
        .background(Color(argb: 0x59000000))
        .overlay(alignment: .top) {
            LinearGradient(colors: [Color(argb: 0x99000000), Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 12)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(argb: 0x80000000), lineWidth: 1))
    }

    // MARK: - Catalog

    @ViewBuilder
    private var catalogSection: some View {
        SectionEyebrow(text: "CATALOG", size: 10, tracking: 3.4)

        let genesis = demoStates.first
        CatalogRowCard(
            name: "The Genesis",
            subtitle: "A 9-day taste of the morning experience",
            pill: CatalogRules.genesisPill(
                completedDays: genesis?.completedDays ?? 0,
                currentDay: genesis?.currentDay ?? 1,
                isActive: genesis?.isActive ?? false
            )
        )

        ForEach(CatalogRules.ownedRows(facts), id: \.id) { row in
            let entity = journeys.first(where: { $0.id == row.id })
            CatalogRowCard(
                name: entity?.title ?? row.id,
                subtitle: entity?.framingLine ?? "",
                pill: CatalogRules.journeyPill(row)
            )
            if CatalogRules.songsVisible(row) {
                songList(tracks(forJourneyId: row.id))
            }
        }

        if CatalogRules.isCatalystOwned(facts) {
            CatalogRowCard(
                name: "The Catalyst Tracks",
                subtitle: "Five songs for five kinds of morning",
                pill: CatalogRules.Pill(label: "Owned", style: .owned)
            )
            songList(tracks(forJourneyId: CatalogRules.catalystId))
        }
    }

    private func songList(_ tracks: [LibraryPlayer.Track]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.songId) { index, track in
                let isCurrent = library.current?.songId == track.songId
                Button { library.play(track) } label: {
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", index + 1))
                            .font(.mono(10))
                            .tracking(1)
                            .foregroundColor(BrassPaper.brassHighlight.opacity(0.50))
                        Text(track.title)
                            .font(.playfair(14, semibold: isCurrent))
                            .foregroundColor(isCurrent ? BrassPaper.brassHighlight : BrassPaper.brassHighlight.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text(isCurrent ? "\u{25B6}" : "\u{25B7}")
                            .font(.system(size: 14))
                            .foregroundColor(isCurrent ? BrassPaper.brassHighlight : BrassPaper.brassHighlight.opacity(0.50))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isCurrent ? BrassPaper.brass2.opacity(0.12) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < tracks.count - 1 {
                    Rectangle()
                        .fill(BrassPaper.brass2.opacity(0.15))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)
                }
            }
        }
        .padding(.vertical, 4)
        .background(BrassPaper.plaqueFill)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(colors: [BrassPaper.brass2.opacity(0.25), BrassPaper.brassDeep.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Starred

    private var starredSection: some View {
        let previewCount = 3
        let hasMore = starred.count > previewCount
        let visible = (starredExpanded || !hasMore) ? Array(starred) : Array(starred.prefix(previewCount))
        return VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(text: "STARRED", size: 10, tracking: 3.4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(visible, id: \.songId) { star in
                    HStack(spacing: 8) {
                        Text("\u{2605}")
                            .font(.system(size: 14))
                            .foregroundColor(Color(argb: 0xFFD4A843))
                        Text(starredTitle(star.songId))
                            .font(.playfair(14))
                            .foregroundColor(BrassPaper.brassHighlight)
                            .lineLimit(1)
                        Spacer()
                        Text(Self.libraryName(songs.first(where: { $0.id == star.songId })?.journeyId ?? ""))
                            .font(.mono(9))
                            .tracking(1.8)
                            .foregroundColor(BrassPaper.inkSoft.opacity(0.70))
                            .lineLimit(1)
                    }
                }
                if hasMore {
                    Button { starredExpanded.toggle() } label: {
                        Text(starredExpanded ? "Show less" : "Show all (\(starred.count))")
                            .font(.playfair(12))
                            .foregroundColor(BrassPaper.brass2)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrassPaper.plaqueFill)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(colors: [BrassPaper.brass2.opacity(0.30), BrassPaper.brassDeep.opacity(0.15)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("✦  UPTIME PRIZES  ✦")
            .font(.mono(9))
            .tracking(2.7)
            .foregroundColor(BrassPaper.inkSoft.opacity(0.60))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }

    // MARK: - Lookups

    private func tracks(forJourneyId journeyId: String) -> [LibraryPlayer.Track] {
        audioManager.songs(forJourneyId: journeyId).map { song in
            LibraryPlayer.Track(
                songId: song.id,
                title: song.title,
                fileStem: song.fileStem,
                subdirectory: "Audio/\(journeyId)",
                startMs: song.fullRegion.startMs,
                endMs: song.fullRegion.endMs
            )
        }
    }

    private func starredTitle(_ songId: String) -> String {
        if let title = songs.first(where: { $0.id == songId })?.title, !title.isEmpty { return title }
        return songId.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func skip(by offset: Int) {
        guard let current = library.current else { return }
        let list = playlist
        guard let index = list.firstIndex(where: { $0.songId == current.songId }) else { return }
        let target = index + offset
        guard list.indices.contains(target) else { return }
        library.play(list[target])
    }

    static func libraryName(_ journeyId: String) -> String {
        journeyId.split(separator: "-").map { String($0.prefix(1)).uppercased() + String($0.dropFirst()) }.joined(separator: " ")
    }

    static func format(ms: Int) -> String {
        let seconds = ms / 1000
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// MARK: - Pieces

/// A catalog row: brass emblem, name, one-line subtitle, state pill.
private struct CatalogRowCard: View {
    let name: String
    let subtitle: String
    let pill: CatalogRules.Pill

    var body: some View {
        PlaqueCard(horizontalPadding: 16, verticalPadding: 14) {
            HStack(spacing: 12) {
                Text(name.first.map { String($0).uppercased() } ?? "")
                    .font(.playfair(18, semibold: true))
                    .foregroundColor(BrassPaper.ink)
                    .shadow(color: Color.white.opacity(0.40), radius: 1, x: 0, y: 1)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [BrassPaper.brassDeep, BrassPaper.brass3, BrassPaper.brass1, BrassPaper.brass3],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(BrassPaper.brassHighlight.opacity(0.50), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.playfair(17, semibold: true))
                        .foregroundColor(BrassPaper.brassHighlight.opacity(0.85))
                        .lineLimit(1)
                        .plaqueTextShadow()
                    Text(subtitle)
                        .font(.playfair(11))
                        .foregroundColor(BrassPaper.screenGlow)
                        .lineLimit(1)
                }
                Spacer(minLength: 10)
                switch pill.style {
                case .active, .price:
                    BrassPillLabel(text: pill.label)
                case .owned:
                    OwnedPillLabel(text: pill.label)
                }
            }
        }
    }
}

/// The brass play/pause button of the Morning Prize player.
private struct BrassPlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Canvas { context, size in
                if isPlaying {
                    let barWidth = size.width * 0.26
                    let gap = size.width * 0.20
                    for x in [size.width / 2 - gap / 2 - barWidth / 2, size.width / 2 + gap / 2 + barWidth / 2] {
                        var bar = Path()
                        bar.move(to: CGPoint(x: x, y: size.height * 0.12))
                        bar.addLine(to: CGPoint(x: x, y: size.height * 0.88))
                        context.stroke(bar, with: .color(BrassPaper.raisedInk), style: StrokeStyle(lineWidth: barWidth, lineCap: .round))
                    }
                } else {
                    var triangle = Path()
                    triangle.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.15))
                    triangle.addLine(to: CGPoint(x: size.width * 0.85, y: size.height * 0.50))
                    triangle.addLine(to: CGPoint(x: size.width * 0.25, y: size.height * 0.85))
                    triangle.closeSubpath()
                    context.fill(triangle, with: .color(BrassPaper.raisedInk))
                }
            }
            .frame(width: 18, height: 18)
            .frame(width: 76, height: 48)
            .raisedBrass()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

/// Eight gold bars; they move while music plays and rest in an arch when not.
private struct GoldWaveform: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: !animated)) { timeline in
            let tick = animated ? timeline.date.timeIntervalSinceReferenceDate * 2.5 : 0
            Canvas { context, size in
                let bars = 8
                let gap = size.width / CGFloat(bars)
                let barWidth = gap * 0.55
                for i in 0..<bars {
                    let phase = Double(i) * 0.7 + tick
                    let phase2 = Double(i) * 1.3 - tick * 0.8
                    let factor: Double = animated
                        ? 0.2 + 0.8 * (0.5 + 0.5 * sin(phase)) * (0.6 + 0.4 * cos(phase2))
                        : 0.3 + 0.5 * sin(Double(i) * Double.pi / Double(bars - 1))
                    let height = CGFloat(factor) * size.height * 0.9
                    let x = CGFloat(i) * gap + gap / 2
                    let top = size.height / 2 - height / 2
                    var bar = Path()
                    bar.move(to: CGPoint(x: x, y: top))
                    bar.addLine(to: CGPoint(x: x, y: top + height))
                    context.stroke(
                        bar,
                        with: .linearGradient(
                            Gradient(colors: [BrassPaper.brassHighlight, BrassPaper.brass1, BrassPaper.brass3]),
                            startPoint: CGPoint(x: x, y: 0),
                            endPoint: CGPoint(x: x, y: size.height)
                        ),
                        style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
                    )
                    var shine = Path()
                    shine.move(to: CGPoint(x: x, y: top))
                    shine.addLine(to: CGPoint(x: x, y: top + barWidth * 0.8))
                    context.stroke(
                        shine,
                        with: .color(Color.white.opacity(0.3)),
                        style: StrokeStyle(lineWidth: barWidth * 0.6, lineCap: .round)
                    )
                }
            }
        }
    }
}

/// The journey's progress: a recessed track with a brass fill.
private struct JourneyBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(argb: 0x80000000))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(argb: 0x99000000), lineWidth: 1))
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [BrassPaper.brass3, BrassPaper.brass2, BrassPaper.brass1, BrassPaper.brassHighlight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(fraction))
            }
        }
        .frame(height: 10)
    }
}
