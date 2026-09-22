import XCTest
import SwiftData
@testable import UpTimePrizes

// MARK: - Fixture manifest
//
// A small Android-schema manifest used to test parsing, ordering and
// wrap-around without depending on the bundled resource. Titles are chosen
// so that alphabetical order differs from sortOrder: sorting by title would
// fail the order tests, as it must (no journey is ever alphabetical).

private let fixtureManifestJSON = """
{
  "version": "2.0",
  "total_songs": 13,
  "generated_at": "test",
  "journeys": [
    { "journeyId": "genesis", "title": "The Genesis", "category": "demo", "totalDays": 9,
      "productId": "", "price": "Free", "description": "d", "sortOrder": 0,
      "packName": "", "framingLine": "f", "entitlementId": "" },
    { "journeyId": "cast-prelude", "title": "The Cast Prelude", "category": "signature", "totalDays": 8,
      "productId": "com.uptime.prizes.signature", "price": "$2.99", "description": "d", "sortOrder": 1,
      "packName": "signature", "framingLine": "f", "entitlementId": "" }
  ],
  "songs": [
    { "id": "g-2", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "zeta.ogg",
      "sortOrder": 2, "title": "Zeta", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 30058}, "loop2Region": {"startMs": 33994, "endMs": 55715},
      "fullRegion": {"startMs": 59737, "endMs": 229592} },
    { "id": "g-1", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "alpha.ogg",
      "sortOrder": 1, "title": "Alpha", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "g-3", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "mid.ogg",
      "sortOrder": 3, "title": "Mid", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "g-4", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "d4.ogg",
      "sortOrder": 4, "title": "Beta", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "g-5", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "d5.ogg",
      "sortOrder": 5, "title": "Yarn", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-1", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp1.ogg",
      "sortOrder": 1, "title": "CP One", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-2", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp2.ogg",
      "sortOrder": 2, "title": "CP Two", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-3", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp3.ogg",
      "sortOrder": 3, "title": "CP Three", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-4", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp4.ogg",
      "sortOrder": 4, "title": "CP Four", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-5", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp5.ogg",
      "sortOrder": 5, "title": "CP Five", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-6", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp6.ogg",
      "sortOrder": 6, "title": "CP Six", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-7", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp7.ogg",
      "sortOrder": 7, "title": "CP Seven", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-8", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp8.ogg",
      "sortOrder": 8, "title": "CP Eight", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} }
  ]
}
"""

// MARK: - Manifest rules

final class ManifestRulesTests: XCTestCase {

    private var manifest: UpTimeManifest!

    override func setUpWithError() throws {
        manifest = try XCTUnwrap(UpTimeManifest.decode(from: Data(fixtureManifestJSON.utf8)))
    }

    func testAndroidSchemaParses() {
        XCTAssertEqual(manifest.journeys.count, 2)
        XCTAssertEqual(manifest.songs.count, 13)
        XCTAssertEqual(manifest.journey(withId: "genesis")?.totalDays, 9)
    }

    func testSongOrderIsSortOrderNeverAlphabetical() {
        let titles = manifest.songs(forJourneyId: "genesis").map { $0.title }
        // sortOrder order — the fixture's alphabetical order would be
        // Alpha, Beta, Mid, Yarn, Zeta; the manifest order must win.
        XCTAssertEqual(titles, ["Alpha", "Zeta", "Mid", "Beta", "Yarn"])
    }

    func testMorningLookupWrapsRound() {
        // 5-song Genesis: morning 6 replays song 1; morning 9 is song 4.
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 1)?.sortOrder, 1)
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 6)?.sortOrder, 1)
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 9)?.sortOrder, 4)
        // 8-song journey: morning 9 replays song 1 (the nine-mornings rule).
        XCTAssertEqual(manifest.song(forJourneyId: "cast-prelude", morning: 9)?.sortOrder, 1)
        XCTAssertEqual(manifest.song(forJourneyId: "cast-prelude", morning: 8)?.sortOrder, 8)
    }

    func testMorningLookupNeverFreezesAfterCompletion() {
        // Way past completion the index still resolves, wrapping round.
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 23)?.sortOrder, 3)
        XCTAssertNotNil(manifest.song(forJourneyId: "cast-prelude", morning: 100))
    }

    func testFileStemStripsExtension() {
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 2)?.fileStem, "zeta")
    }

    func testRealRegionsAreCarried() throws {
        let zeta = try XCTUnwrap(manifest.song(forJourneyId: "genesis", morning: 2))
        XCTAssertEqual(zeta.loop1Region, ManifestRegion(startMs: 0, endMs: 30058))
        XCTAssertEqual(zeta.loop2Region, ManifestRegion(startMs: 33994, endMs: 55715))
        XCTAssertEqual(zeta.fullRegion, ManifestRegion(startMs: 59737, endMs: 229592))
    }
}

// MARK: - Bundled manifest (runs only when the resource is in the test bundle)

final class BundledManifestTests: XCTestCase {

    func testBundledManifestMatchesAndroidCatalog() throws {
        guard let manifest = UpTimeManifest.loadFromBundle() else {
            throw XCTSkip("uptime_full_manifest.json not present in this bundle")
        }
        XCTAssertGreaterThanOrEqual(manifest.journeys.count, 6, "Expected the full catalog")
        XCTAssertEqual(manifest.songs(forJourneyId: "genesis").count, 5)
        // The placeholder pattern from the June build (0/30000/60000 for every
        // song) must never come back: regions are per-song measurements.
        let placeholderCount = manifest.songs.filter {
            $0.loop1Region == ManifestRegion(startMs: 0, endMs: 30000) &&
            $0.loop2Region == ManifestRegion(startMs: 30000, endMs: 60000)
        }.count
        XCTAssertEqual(placeholderCount, 0, "Found placeholder regions — real measurements required")
    }
}

// MARK: - Journey progression and independence

@MainActor
final class JourneyProgressionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var alarmEngine: AlarmEngine!

    override func setUpWithError() throws {
        let schema = Schema([JourneyEntity.self, SongEntity.self, DemoStateEntity.self, AlarmEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        seedFromFixture()
        alarmEngine = AlarmEngine(context: context)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        alarmEngine = nil
    }

    /// Seeds journeys directly from the fixture manifest, mirroring
    /// DatabaseSeeder's rules (which read the bundled file).
    private func seedFromFixture() {
        guard let manifest = UpTimeManifest.decode(from: Data(fixtureManifestJSON.utf8)) else { return }
        context.insert(DemoStateEntity())
        context.insert(AlarmEntity())
        for mj in manifest.journeys {
            let isGenesis = mj.journeyId == "genesis"
            context.insert(JourneyEntity(
                id: mj.journeyId, title: mj.title, descriptionText: mj.description,
                framingLine: mj.framingLine, totalDays: mj.totalDays, sortOrder: mj.sortOrder,
                packName: mj.packName, productId: mj.productId, entitlementId: mj.entitlementId,
                isPurchaseOffered: !mj.productId.isEmpty,
                isActive: isGenesis,
                purchaseState: isGenesis ? "ACTIVE_IN_PROGRESS" : "NOT_OWNED",
                completedDays: 0, currentDay: 1
            ))
        }
        for ms in manifest.songs {
            context.insert(SongEntity(
                id: ms.id, title: ms.title, journeyId: ms.journeyId,
                sortOrder: ms.sortOrder, fileStem: ms.fileStem,
                isAvailable: ms.journeyId == "genesis"
            ))
        }
        try? context.save()
    }

    // MARK: Initial state

    func testOnlyGenesisIsActiveOnFirstLaunch() throws {
        let journeys = try context.fetch(FetchDescriptor<JourneyEntity>())
        let active = journeys.filter { $0.isActive }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, "genesis")
    }

    func testGenesisSongsAvailableOthersNot() throws {
        let songs = try context.fetch(FetchDescriptor<SongEntity>())
        XCTAssertTrue(songs.filter { $0.journeyId == "genesis" }.allSatisfy { $0.isAvailable })
        XCTAssertTrue(songs.filter { $0.journeyId != "genesis" }.allSatisfy { !$0.isAvailable })
    }

    func testDiscoverLockedInitially() throws {
        let demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertFalse(demo?.isPurchaseOffered ?? true)
    }

    // MARK: Progression

    func testDismissIncrementsCountAndMovesMorningForward() throws {
        alarmEngine.handleAlarmDismissed()
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 1)
        XCTAssertEqual(genesis?.currentDay, 2)
    }

    func testNineDismissalsUnlockDiscover() throws {
        for _ in 0..<9 { alarmEngine.handleAlarmDismissed() }
        let demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertTrue(demo?.isPurchaseOffered ?? false)
    }

    func testCompletionSetsUnlockedStateAndIndexKeepsMoving() throws {
        for _ in 0..<9 { alarmEngine.handleAlarmDismissed() }
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.purchaseState, "UNLOCKED_FOR_PLAYBACK")
        // The morning number must keep moving after completion — never freeze.
        alarmEngine.handleAlarmDismissed()
        XCTAssertEqual(genesis?.currentDay, 11)
    }

    // MARK: Independence

    func testDismissingGenesisNeverAdvancesAnotherJourney() throws {
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "cast-prelude" })
        if let castPrelude = try context.fetch(fetch).first {
            castPrelude.purchaseState = "ACTIVE_IN_PROGRESS"
            castPrelude.completedDays = 5
            castPrelude.isActive = false
        }
        try context.save()

        alarmEngine.handleAlarmDismissed() // Genesis is active

        let castPrelude = try context.fetch(fetch).first
        XCTAssertEqual(castPrelude?.completedDays, 5)
    }

    func testSwitchingJourneysPreservesProgress() throws {
        for _ in 0..<3 { alarmEngine.handleAlarmDismissed() }
        let journeys = try context.fetch(FetchDescriptor<JourneyEntity>())
        for journey in journeys { journey.isActive = journey.id == "cast-prelude" }
        try context.save()

        let genesis = journeys.first { $0.id == "genesis" }
        XCTAssertEqual(genesis?.completedDays, 3, "Switching must preserve each journey's place")
        XCTAssertEqual(journeys.filter { $0.isActive }.count, 1)
    }

    // MARK: StageCoordinator

    func testStageCoordinatorAdvancesInOrder() {
        let coordinator = StageCoordinator()
        XCTAssertEqual(coordinator.currentStage, .stage1)
        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .stage2)
        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .stage3)
    }

    func testStageCoordinatorReplayDoesNotAdvanceBeyond() {
        let coordinator = StageCoordinator()
        coordinator.advanceStage()
        coordinator.advanceStage()
        coordinator.advanceStage()
        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .replay)
    }
}
