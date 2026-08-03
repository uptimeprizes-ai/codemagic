import Foundation
import SwiftData
import CryptoKit

// MARK: - DatabaseSeeder

/// Seeds the SwiftData database on first launch and on every launch where
/// the bundled manifest has changed.
///
/// Bug 3 fix: Computes a SHA-256 fingerprint of the bundled manifest's song data.
/// On every launch, compares the stored fingerprint against the current manifest.
/// If they differ (e.g., after an app update with new region timestamps), all song
/// entries are force-refreshed from the bundled manifest — even if they already exist.
/// This prevents stale iCloud-restored region data from causing incorrect loop positions.
struct DatabaseSeeder {

    // MARK: - UserDefaults keys

    private static let manifestFingerprintKey = "com.uptimeprizes.manifestFingerprint"

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

    // MARK: - Seed entry point

    @MainActor
    static func seed(context: ModelContext) {
        seedDemoState(context: context)
        seedAlarm(context: context)
        seedJourneys(context: context)
        seedSongsWithFingerprintCheck(context: context)
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

    // MARK: - Bug 3 fix: Manifest fingerprint-gated song seeding

    @MainActor
    private static func seedSongsWithFingerprintCheck(context: ModelContext) {
        guard let manifestData = loadManifestData(),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestData) else {
            return
        }

        // Compute SHA-256 fingerprint of the manifest's song data
        let currentFingerprint = sha256(manifestData)
        let storedFingerprint = UserDefaults.standard.string(forKey: manifestFingerprintKey) ?? ""

        let fetchSongs = FetchDescriptor<SongEntity>()
        let songCount = (try? context.fetchCount(fetchSongs)) ?? 0
        let manifestChanged = currentFingerprint != storedFingerprint

        if songCount == 0 || manifestChanged {
            if manifestChanged && songCount > 0 {
                print("[DatabaseSeeder] Manifest fingerprint changed — force-refreshing song region data.")
                // Delete all existing demo songs so they get re-seeded with fresh region data
                let fetchDemoSongs = FetchDescriptor<SongEntity>(
                    predicate: #Predicate { $0.libraryId == "demo" }
                )
                if let existing = try? context.fetch(fetchDemoSongs) {
                    for song in existing { context.delete(song) }
                }
            }

            // Seed demo songs from manifest
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

            // Seed Catalyst Track stubs (only if not already present)
            let catalystSongs: [(id: String, title: String, day: Int, filename: String)] = [
                ("special-day-01", "The Anniversary of You", 1, "the_anniversary_of_you"),
                ("special-day-02", "The Vacation Kickoff", 2, "the_vacation_kickoff"),
                ("special-day-03", "My Own Company", 3, "my_own_company"),
                ("special-day-04", "Step Into The Room", 4, "step_into_the_room"),
                ("special-day-05", "The Slate is Washed", 5, "the_slate_is_washed")
            ]
            let fetchCatalyst = FetchDescriptor<SongEntity>(
                predicate: #Predicate { $0.libraryId == "special-day" }
            )
            if (try? context.fetchCount(fetchCatalyst)) == 0 {
                for song in catalystSongs {
                    let entity = SongEntity(
                        id: song.id,
                        title: song.title,
                        libraryId: "special-day",
                        dayNumber: song.day,
                        filename: song.filename,
                        isAvailable: false
                    )
                    context.insert(entity)
                }
            }

            // Store the new fingerprint
            UserDefaults.standard.set(currentFingerprint, forKey: manifestFingerprintKey)
        }
    }

    // MARK: - Helpers

    private static func loadManifestData() -> Data? {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - iCloud Backup Exclusion

/// Call this once on first launch to exclude the SwiftData store from iCloud backup.
/// This prevents stale region data from being restored from an old backup.
/// Must be called after the ModelContainer is created.
struct BackupExclusion {
    @MainActor
    static func excludeSwiftDataStoreFromBackup() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        // SwiftData stores its database in Application Support
        let storeDirectory = appSupport
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: storeDirectory,
                includingPropertiesForKeys: nil
            )
            for url in contents where url.pathExtension == "store" || url.lastPathComponent.contains("default") {
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableURL = url
                try mutableURL.setResourceValues(resourceValues)
                print("[BackupExclusion] Excluded from iCloud backup: \(url.lastPathComponent)")
            }
        } catch {
            print("[BackupExclusion] Could not exclude store from backup: \(error)")
        }
    }
}
