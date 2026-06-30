import Foundation
import SwiftData

struct DatabaseSeeder {

    // MARK: - Manifest Codable types

    private struct Manifest: Codable {
        let version: Int
        let libraries: [String: Library]
    }

    private struct Library: Codable {
        let title: String
        let songs: [ManifestSong]
    }

    private struct ManifestSong: Codable {
        let id: String
        let title: String
        let filename: String
        let dayNumber: Int
        let regions: Regions
    }

    private struct Regions: Codable {
        let stage1: Region
        let stage2: Region
        let stage3: Region
    }

    private struct Region: Codable {
        let startMs: Int
        let endMs: Int
    }

    // MARK: - Seed

    @MainActor
    static func seed(context: ModelContext) {
        seedDemoState(context: context)
        seedAlarm(context: context)
        seedJourneys(context: context)
        seedSongs(context: context)
        try? context.save()
    }

    // MARK: - Private helpers

    @MainActor
    private static func seedDemoState(context: ModelContext) {
        let fetchDemo = FetchDescriptor<DemoStateEntity>()
        if (try? context.fetchCount(fetchDemo)) == 0 {
            context.insert(DemoStateEntity())
        }
    }

    @MainActor
    private static func seedAlarm(context: ModelContext) {
        let fetchAlarm = FetchDescriptor<AlarmEntity>()
        if (try? context.fetchCount(fetchAlarm)) == 0 {
            context.insert(AlarmEntity())
        }
    }

    @MainActor
    private static func seedJourneys(context: ModelContext) {
        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard (try? context.fetchCount(fetchJourneys)) == 0 else { return }

        let genesis = JourneyEntity(
            id: "demo",
            title: "The Genesis",
            descriptionText: "Five original melodies inspired by Big Band Swing — the opening chapter of your morning experience.",
            type: "DEMO",
            totalDays: 9,
            isPurchaseOffered: false,
            isActive: true,
            purchaseState: "ACTIVE_IN_PROGRESS",
            completedDays: 0,
            currentDay: 1
        )
        context.insert(genesis)

        let overture = JourneyEntity(
            id: "library-a",
            title: "The Overture",
            descriptionText: "Forty-five original songs. One per morning. Complete all 45 days to unlock the full library for free playback.",
            type: "LIBRARY_A",
            totalDays: 45,
            isPurchaseOffered: true,
            isActive: false,
            purchaseState: "NOT_OWNED",
            completedDays: 0,
            currentDay: 1
        )
        context.insert(overture)

        let castPrelude = JourneyEntity(
            id: "signature",
            title: "The Cast Prelude",
            descriptionText: "Eight songs from the Signature Series. Complete all 8 mornings to unlock free playback.",
            type: "SIGNATURE",
            totalDays: 8,
            isPurchaseOffered: true,
            isActive: false,
            purchaseState: "NOT_OWNED",
            completedDays: 0,
            currentDay: 1
        )
        context.insert(castPrelude)

        let catalyst = JourneyEntity(
            id: "special-day",
            title: "The Catalyst Tracks",
            descriptionText: "Five songs composed for specific mornings. Freely playable from day one.",
            type: "SPECIAL_DAY",
            totalDays: 5,
            isPurchaseOffered: true,
            isActive: false,
            purchaseState: "NOT_OWNED",
            completedDays: 0,
            currentDay: 1
        )
        context.insert(catalyst)
    }

    @MainActor
    private static func seedSongs(context: ModelContext) {
        let fetchSongs = FetchDescriptor<SongEntity>()
        guard (try? context.fetchCount(fetchSongs)) == 0 else { return }

        // Seed demo songs from manifest.json
        if let manifest = loadManifest() {
            for (libraryId, library) in manifest.libraries {
                for song in library.songs {
                    let entity = SongEntity(
                        id: song.id,
                        title: song.title,
                        libraryId: libraryId,
                        dayNumber: song.dayNumber,
                        filename: song.filename,
                        isAvailable: true
                    )
                    context.insert(entity)
                }
            }
        }

        // Seed Catalyst Tracks (audio delivered after purchase)
        let catalystSongs: [(id: String, title: String, day: Int, filename: String)] = [
            ("special-day-01", "The Anniversary of You", 1, "the_anniversary_of_you"),
            ("special-day-02", "The Vacation Kickoff", 2, "the_vacation_kickoff"),
            ("special-day-03", "My Own Company", 3, "my_own_company"),
            ("special-day-04", "Step Into The Room", 4, "step_into_the_room"),
            ("special-day-05", "The Slate is Washed", 5, "the_slate_is_washed")
        ]
        for song in catalystSongs {
            let entity = SongEntity(
                id: song.id,
                title: song.title,
                libraryId: "special-day",
                dayNumber: song.day,
                filename: song.filename,
                isAvailable: false // available after purchase + asset delivery
            )
            context.insert(entity)
        }
    }

    private static func loadManifest() -> Manifest? {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }
}
