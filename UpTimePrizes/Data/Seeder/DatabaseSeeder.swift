import Foundation
import SwiftData
import CryptoKit

// MARK: - DatabaseSeeder

/// Seeds the SwiftData database from uptime_full_manifest.json (the Android
/// manifest, shared verbatim) on first launch, and refreshes it on every
/// launch where the manifest has changed.
///
/// Rules this encodes (handoff §3.1, §2.2):
/// - The manifest is the single source of truth. Journey and song rows are
///   projections of it; regions are never copied into the database.
/// - Identity is journeyId. Rows whose ids are no longer in the manifest
///   (e.g. the retired "demo"/"library-a" ids) are deleted.
/// - A manifest fingerprint change force-refreshes every song row, so a
///   database restored from backup can never carry stale song timings.
/// - Journey progress fields (isActive, purchaseState, completedDays,
///   currentDay) belong to the device and are never overwritten by a refresh.
struct DatabaseSeeder {

    private static let manifestFingerprintKey = "com.uptimeprizes.manifestFingerprint"

    // MARK: - Seed entry point

    @MainActor
    static func seed(context: ModelContext) {
        seedDemoState(context: context)
        seedAlarm(context: context)

        guard let data = loadManifestData(),
              let manifest = UpTimeManifest.decode(from: data) else {
            UpTimeLog.seed.error("[SEED] manifest missing or undecodable — nothing seeded")
            return
        }

        let fingerprint = sha256(data)
        let stored = UserDefaults.standard.string(forKey: manifestFingerprintKey) ?? ""
        let manifestChanged = fingerprint != stored

        syncJourneys(from: manifest, context: context)
        syncSongs(from: manifest, context: context, forceRefresh: manifestChanged)

        if manifestChanged {
            UserDefaults.standard.set(fingerprint, forKey: manifestFingerprintKey)
        }
        try? context.save()
    }

    // MARK: - Journeys

    @MainActor
    private static func syncJourneys(from manifest: UpTimeManifest, context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<JourneyEntity>())) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let manifestIds = Set(manifest.journeys.map { $0.journeyId })

        for mj in manifest.journeys {
            if let row = existingById[mj.journeyId] {
                // Metadata refresh only — progress is device state.
                row.title = mj.title
                row.descriptionText = mj.description
                row.framingLine = mj.framingLine
                row.totalDays = mj.totalDays
                row.sortOrder = mj.sortOrder
                row.packName = mj.packName
                row.productId = mj.productId
                row.entitlementId = mj.entitlementId
                row.isPurchaseOffered = !mj.productId.isEmpty
            } else {
                let isGenesis = mj.journeyId == "genesis"
                context.insert(JourneyEntity(
                    id: mj.journeyId,
                    title: mj.title,
                    descriptionText: mj.description,
                    framingLine: mj.framingLine,
                    totalDays: mj.totalDays,
                    sortOrder: mj.sortOrder,
                    packName: mj.packName,
                    productId: mj.productId,
                    entitlementId: mj.entitlementId,
                    isPurchaseOffered: !mj.productId.isEmpty,
                    isActive: isGenesis && existing.isEmpty,
                    purchaseState: isGenesis ? "ACTIVE_IN_PROGRESS" : "NOT_OWNED",
                    completedDays: 0,
                    currentDay: 1
                ))
            }
        }

        // Delete rows for ids the manifest no longer knows (retired catalog ids).
        for row in existing where !manifestIds.contains(row.id) {
            context.delete(row)
        }
    }

    // MARK: - Songs

    @MainActor
    private static func syncSongs(from manifest: UpTimeManifest, context: ModelContext, forceRefresh: Bool) {
        let fetch = FetchDescriptor<SongEntity>()
        let count = (try? context.fetchCount(fetch)) ?? 0
        guard count == 0 || forceRefresh else { return }

        if count > 0 {
            UpTimeLog.seed.notice("[SEED] manifest fingerprint changed — refreshing all song rows")
            if let existing = try? context.fetch(fetch) {
                for song in existing { context.delete(song) }
            }
        }

        // Genesis ships inside the app; every other journey's audio arrives by
        // download, so its songs start unavailable until delivery marks them.
        for ms in manifest.songs {
            context.insert(SongEntity(
                id: ms.id,
                title: ms.title,
                journeyId: ms.journeyId,
                sortOrder: ms.sortOrder,
                fileStem: ms.fileStem,
                isAvailable: ms.journeyId == "genesis"
            ))
        }
    }

    // MARK: - Singletons

    @MainActor
    private static func seedDemoState(context: ModelContext) {
        if (try? context.fetchCount(FetchDescriptor<DemoStateEntity>())) == 0 {
            context.insert(DemoStateEntity())
        }
    }

    @MainActor
    private static func seedAlarm(context: ModelContext) {
        if (try? context.fetchCount(FetchDescriptor<AlarmEntity>())) == 0 {
            context.insert(AlarmEntity())
        }
    }

    // MARK: - Helpers

    private static func loadManifestData() -> Data? {
        guard let url = Bundle.main.url(forResource: UpTimeManifest.resourceName, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - iCloud Backup Exclusion

/// Call once on first launch to exclude the SwiftData store from iCloud backup,
/// so stale region/progress data is never restored from an old backup.
struct BackupExclusion {
    @MainActor
    static func excludeSwiftDataStoreFromBackup() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        do {
            let contents = try fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
            for url in contents where url.pathExtension == "store" || url.lastPathComponent.contains("default") {
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableURL = url
                try mutableURL.setResourceValues(resourceValues)
                UpTimeLog.seed.info("[SEED] excluded from iCloud backup: \(url.lastPathComponent, privacy: .public)")
            }
        } catch {
            UpTimeLog.seed.error("[SEED] backup exclusion failed: \(error, privacy: .public)")
        }
    }
}
