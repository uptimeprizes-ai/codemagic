import XCTest
import SwiftData
import CryptoKit
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
    { "journeyId": "cast-prelude", "title": "The Cast Prelude", "category": "signature", "totalDays": 9,
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

// MARK: - Bundled manifest
//
// The test host IS the app, so Bundle.main is the app bundle. If the manifest
// is missing here, the shipped app is broken — that is a failure, never a skip.

final class BundledManifestTests: XCTestCase {

    func testBundledManifestMatchesAndroidCatalog() throws {
        let manifest = try XCTUnwrap(
            UpTimeManifest.loadFromBundle(),
            "uptime_full_manifest.json is missing from the app bundle — the packaging is broken"
        )
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

// MARK: - Bundled audio
//
// Builds #1–20 shipped a ~3 MB ipa with NO audio in it — the project config
// silently dropped every song, and nothing failed. This test makes that
// impossible to repeat: it resolves each Genesis file through the exact
// subdirectory the app plays from, and verifies the bytes are the pipeline's
// approved encodes (SHA-256 from 01_IOS_M4A/genesis/ios_regions.json).

final class BundledAudioTests: XCTestCase {

    private let expected: [(stem: String, sha256: String)] = [
        ("bright_side_swing", "02a71fd10c0fddf4bafe06c414ef37b3aa6de2a518866bede3601e2fdf5d12b9"),
        ("the_uptime_swing", "2a823fdc6b4f1c96232250d6a3447d7ae38e94fd54393793db9ed565317922a7"),
        ("wake_up", "54f0a283694bb0bdd214fb6a82ccd705dfa3c4f9df26334bf2e0943105cc2fad"),
        ("no_permission", "f71f52f06b0c2adf9dea9519b66fb2dc5b088068ee208d3d60dbd1fbd0af247d"),
        ("uptime_go_go", "0f68976ffafc923aac82eff58e58857ebefec09390ec17e44f40abc020df208b")
    ]

    func testAllGenesisAudioIsInTheBundle() throws {
        for entry in expected {
            let url = Bundle.main.url(
                forResource: entry.stem, withExtension: "m4a", subdirectory: "Audio/genesis"
            )
            XCTAssertNotNil(url, "\(entry.stem).m4a missing from Audio/genesis — the packaging flaw is back")
        }
    }

    func testGenesisAudioIsThePipelinesApprovedEncode() throws {
        for entry in expected {
            guard let url = Bundle.main.url(
                forResource: entry.stem, withExtension: "m4a", subdirectory: "Audio/genesis"
            ) else { continue } // absence already failed above
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 1_000_000, "\(entry.stem).m4a is implausibly small")
            let digest = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, entry.sha256, "\(entry.stem).m4a is not the pipeline's approved encode")
        }
    }

    func testEveryGenesisManifestSongResolvesToBundledAudio() throws {
        let manifest = try XCTUnwrap(UpTimeManifest.loadFromBundle())
        for song in manifest.songs(forJourneyId: "genesis") {
            let url = Bundle.main.url(
                forResource: song.fileStem, withExtension: "m4a", subdirectory: "Audio/genesis"
            )
            XCTAssertNotNil(url, "Manifest song \(song.id) (\(song.fileStem)) has no bundled audio")
        }
    }
}

// MARK: - Journey progression and independence

@MainActor
final class JourneyProgressionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var alarmEngine: AlarmEngine!

    /// Fixed date anchor; each counted morning advances one calendar day, so
    /// the one-morning-per-day rule never collides inside a test.
    private var testDay = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        let schema = Schema([JourneyEntity.self, SongEntity.self, DemoStateEntity.self, AlarmEntity.self, MorningRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        seedFromFixture()
        alarmEngine = AlarmEngine(context: context)
    }

    /// A full counted morning: new session, sounded audio, next calendar day.
    @discardableResult
    private func dismissMorning(reachedPrize: Bool = true) -> AlarmEngine.MorningOutcome? {
        alarmEngine.beginAlarmSession()
        let outcome = alarmEngine.handleAlarmDismissed(
            audioSounded: true,
            stageAtDismiss: reachedPrize ? "prize" : "invite",
            reachedPrize: reachedPrize,
            date: testDay
        )
        testDay = Calendar.current.date(byAdding: .day, value: 1, to: testDay)!
        return outcome
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
        dismissMorning()
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 1)
        XCTAssertEqual(genesis?.currentDay, 2)
    }

    func testNineDismissalsUnlockDiscover() throws {
        for _ in 0..<9 { dismissMorning() }
        let demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertTrue(demo?.isPurchaseOffered ?? false)
    }

    func testCompletionSetsUnlockedStateAndIndexKeepsMoving() throws {
        for _ in 0..<9 { dismissMorning() }
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.purchaseState, "UNLOCKED_FOR_PLAYBACK")
        // The morning number must keep moving after completion — never freeze.
        dismissMorning()
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

        dismissMorning() // Genesis is active

        let castPrelude = try context.fetch(fetch).first
        XCTAssertEqual(castPrelude?.completedDays, 5)
    }

    func testSwitchingJourneysPreservesProgress() throws {
        for _ in 0..<3 { dismissMorning() }
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

    // MARK: Counting rules (§2.4)

    func testNothingSoundedNothingCounted() throws {
        alarmEngine.beginAlarmSession()
        let outcome = alarmEngine.handleAlarmDismissed(
            audioSounded: false, stageAtDismiss: "invite", reachedPrize: false, date: testDay
        )
        XCTAssertNil(outcome, "No Prize screen without a counted morning")
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 0)
        XCTAssertEqual(MorningLedger(context: context).soundedMorningsCount(), 0)
    }

    func testSecondAlarmSameDayNeverCountsTwice() throws {
        let day = testDay
        alarmEngine.beginAlarmSession()
        XCTAssertNotNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: day
        ))
        alarmEngine.beginAlarmSession() // a new session, same calendar day
        XCTAssertNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: day
        ))
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 1)
    }

    func testOneRecordedMorningPerAlarmSession() throws {
        alarmEngine.beginAlarmSession()
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: testDay)!
        XCTAssertNotNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: testDay
        ))
        // Same session, even on a new calendar day (midnight crossed): no second count.
        XCTAssertNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: day2
        ))
    }

    func testCatalystMorningHoldsStreakAndAdvancesNoJourney() throws {
        // Add the Catalyst journey and make it active.
        context.insert(JourneyEntity(
            id: "catalyst", title: "The Catalyst Tracks", descriptionText: "d",
            framingLine: "f", totalDays: 5, sortOrder: 4, packName: "special_day",
            productId: "com.uptime.prizes.special_day", entitlementId: "",
            isPurchaseOffered: true, isActive: false,
            purchaseState: "UNLOCKED_FOR_PLAYBACK", completedDays: 0, currentDay: 1
        ))
        let journeys = try context.fetch(FetchDescriptor<JourneyEntity>())
        for j in journeys { j.isActive = j.id == "catalyst" }
        try context.save()

        let outcome = try XCTUnwrap(dismissMorning())
        XCTAssertTrue(outcome.heldStreakOnly)
        XCTAssertEqual(outcome.journeyTitle, "The Catalyst Tracks")

        // No journey count moved anywhere.
        for j in try context.fetch(FetchDescriptor<JourneyEntity>()) {
            XCTAssertEqual(j.completedDays, 0)
        }
    }

    // MARK: Nine mornings (founder, 2026-09-15; Android 49/50 parity)

    func testDiscoverOpensAfterNinthCountedMorningNotEighth() throws {
        // The gate reads COUNTED mornings, never "the day you are on" —
        // Android opened a morning early by reading the latter.
        for _ in 0..<8 { dismissMorning() }
        var demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertFalse(demo?.isPurchaseOffered ?? true, "Eight counted mornings must not open Discover")

        dismissMorning() // the ninth
        demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertTrue(demo?.isPurchaseOffered ?? false, "The ninth counted morning opens Discover")
    }

    func testJourneyLengthResyncNeverRelocksAndRidesCountUp() throws {
        // Simulate a device that finished The Cast Prelude at 8/8 before the
        // manifest grew the cycle to 9 (and one journey still in progress).
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "cast-prelude" })
        let finished = try XCTUnwrap(try context.fetch(fetch).first)
        finished.purchaseState = "UNLOCKED_FOR_PLAYBACK"
        finished.completedDays = 8
        finished.totalDays = 8

        let genesisFetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        let inProgress = try XCTUnwrap(try context.fetch(genesisFetch).first)
        inProgress.completedDays = 3
        try context.save()

        let manifest = try XCTUnwrap(UpTimeManifest.decode(from: Data(fixtureManifestJSON.utf8)))
        DatabaseSeeder.syncJourneys(from: manifest, context: context)

        // Finished journey: never re-locks; its count rises with its total.
        XCTAssertEqual(finished.totalDays, 9)
        XCTAssertEqual(finished.completedDays, 9, "8/8 must read 9/9, still complete")
        XCTAssertEqual(finished.purchaseState, "UNLOCKED_FOR_PLAYBACK")

        // In-progress journey: real count preserved, simply further to go.
        XCTAssertEqual(inProgress.totalDays, 9)
        XCTAssertEqual(inProgress.completedDays, 3)
    }
}

// MARK: - Streak rules (§2.4)

@MainActor
final class StreakTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var ledger: MorningLedger!

    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: anchor)!
    }

    override func setUpWithError() throws {
        let schema = Schema([MorningRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        ledger = MorningLedger(context: context)
    }

    private func count(_ offset: Int, catalyst: Bool = false) {
        ledger.record(
            date: day(offset), journeyId: catalyst ? "catalyst" : "genesis",
            stageAtDismiss: "prize", reachedPrize: true,
            heldStreakOnly: catalyst, advancedJourney: !catalyst
        )
    }

    func testConsecutiveMorningsCount() {
        count(0); count(1); count(2)
        XCTAssertEqual(ledger.streak(asOf: day(2)), 3)
    }

    func testStreakShowsZeroTheMomentItIsBroken() {
        count(0); count(1)
        // Last counted day is two days before "today" — not live, shows 0.
        XCTAssertEqual(ledger.streak(asOf: day(3)), 0)
    }

    func testYesterdayKeepsTheRunLive() {
        count(0); count(1)
        XCTAssertEqual(ledger.streak(asOf: day(2)), 2)
    }

    func testCatalystMorningHoldsWithoutExtending() {
        count(0)
        count(1, catalyst: true)
        count(2)
        // Three counted days, but the Catalyst day adds nothing: streak is 2.
        XCTAssertEqual(ledger.streak(asOf: day(2)), 2)
    }

    func testGapBreaksEvenWithCatalystEitherSide() {
        count(0)
        // day 1 has no morning at all
        count(2, catalyst: true)
        count(3)
        // Walk back from day 3: counted day 3 (1), catalyst day 2 (holds),
        // day 1 empty → stop. The day-0 morning is beyond the break.
        XCTAssertEqual(ledger.streak(asOf: day(3)), 1)
    }
}

// MARK: - Prize screen copy selection (§2.5, §2.9)

final class PrizeCopyTests: XCTestCase {

    private func outcome(
        title: String = "The Genesis", morning: Int = 3, total: Int = 9,
        complete: Bool = false, reachedPrize: Bool = false, heldOnly: Bool = false
    ) -> AlarmEngine.MorningOutcome {
        AlarmEngine.MorningOutcome(
            journeyTitle: title, morningNumber: morning, totalDays: total,
            journeyComplete: complete, reachedPrize: reachedPrize, heldStreakOnly: heldOnly
        )
    }

    func testHeaderMorningXofY() {
        XCTAssertEqual(outcome().prizeHeader, "The Genesis · Morning 3 of 9")
    }

    func testHeaderCompleteOnLastMorning() {
        XCTAssertEqual(outcome(morning: 9, complete: true).prizeHeader, "The Genesis · Complete")
    }

    func testHeaderJourneyNameAloneForCatalyst() {
        XCTAssertEqual(outcome(title: "The Catalyst Tracks", heldOnly: true).prizeHeader, "The Catalyst Tracks")
    }

    func testMessagePrizeReached() {
        XCTAssertEqual(outcome(reachedPrize: true).prizeMessage, CuratorCopy.prizeMessagePrizeReached)
    }

    func testMessageDismissedEarly() {
        XCTAssertEqual(outcome().prizeMessage, CuratorCopy.prizeMessageDismissedEarly)
    }

    func testMessageJourneyCompleteWinsOverPrize() {
        XCTAssertEqual(outcome(complete: true, reachedPrize: true).prizeMessage, CuratorCopy.prizeMessageJourneyComplete)
    }

    func testMessageCatalystWinsOverEverything() {
        XCTAssertEqual(outcome(complete: true, reachedPrize: true, heldOnly: true).prizeMessage, CuratorCopy.prizeMessageCatalystOrFallback)
    }
}

// MARK: - Review prompt eligibility (§2.6)

final class ReviewPromptTests: XCTestCase {

    private func ask(
        mornings: Int = 5, attempts: Int = 0, recent: Bool = true,
        alarm: Bool = false, audio: Bool = false, missed: Bool = false
    ) -> Bool {
        ReviewPromptManager.shouldAsk(
            soundedMornings: mornings, attemptsSoFar: attempts,
            lastCountedMorningIsRecent: recent, alarmActive: alarm,
            audioPlaying: audio, hasUnacknowledgedMissedAlarm: missed
        )
    }

    func testAsksAfterFiveSoundedMornings() { XCTAssertTrue(ask()) }
    func testNeverBeforeFiveMornings() { XCTAssertFalse(ask(mornings: 4)) }
    func testAtMostThreeAttempts() {
        XCTAssertTrue(ask(attempts: 2))
        XCTAssertFalse(ask(attempts: 3))
    }
    func testOnlyWhenLastMorningIsRecent() { XCTAssertFalse(ask(recent: false)) }
    func testNeverDuringAlarm() { XCTAssertFalse(ask(alarm: true)) }
    func testNeverWhileAudioPlays() { XCTAssertFalse(ask(audio: true)) }
    func testNeverWithUnacknowledgedMissedAlarm() { XCTAssertFalse(ask(missed: true)) }
}
